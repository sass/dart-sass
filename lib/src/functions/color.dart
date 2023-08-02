// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../callable.dart';
import '../deprecation.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../module/built_in.dart';
import '../util/map.dart';
import '../util/nullable.dart';
import '../util/number.dart';
import '../utils.dart';
import '../value.dart';

/// A regular expression matching the beginning of a proprietary Microsoft
/// filter declaration.
final _microsoftFilterStart = RegExp(r'^[a-zA-Z]+\s*=');

/// If a special number string is detected in these color spaces, even if they
/// were using the one-argument function syntax, we convert it to the three- or
/// four- argument comma-separated syntax for broader browser compatibility.
const _specialCommaSpaces = {ColorSpace.rgb, ColorSpace.hsl};

/// The global definitions of Sass color functions.
final global = UnmodifiableListView([
  // ### RGB
  _channelFunction("red", (color) => color.red, global: true),
  _channelFunction("green", (color) => color.green, global: true),
  _channelFunction("blue", (color) => color.blue, global: true),
  _mix,

  BuiltInCallable.overloadedFunction("rgb", {
    r"$red, $green, $blue, $alpha": (arguments) => _rgb("rgb", arguments),
    r"$red, $green, $blue": (arguments) => _rgb("rgb", arguments),
    r"$color, $alpha": (arguments) => _rgbTwoArg("rgb", arguments),
    r"$channels": (arguments) => _parseChannels("rgb", arguments[0],
        space: ColorSpace.rgb, name: 'channels')
  }),

  BuiltInCallable.overloadedFunction("rgba", {
    r"$red, $green, $blue, $alpha": (arguments) => _rgb("rgba", arguments),
    r"$red, $green, $blue": (arguments) => _rgb("rgba", arguments),
    r"$color, $alpha": (arguments) => _rgbTwoArg("rgba", arguments),
    r"$channels": (arguments) => _parseChannels('rgba', arguments[0],
        space: ColorSpace.rgb, name: 'channels')
  }),

  _function("invert", r"$color, $weight: 100%, $space: null",
      (arguments) => _invert(arguments, global: true)),

  // ### HSL
  _channelFunction("hue", (color) => color.hue, unit: 'deg', global: true),
  _channelFunction("saturation", (color) => color.saturation,
      unit: '%', global: true),
  _channelFunction("lightness", (color) => color.lightness,
      unit: '%', global: true),

  BuiltInCallable.overloadedFunction("hsl", {
    r"$hue, $saturation, $lightness, $alpha": (arguments) =>
        _hsl("hsl", arguments),
    r"$hue, $saturation, $lightness": (arguments) => _hsl("hsl", arguments),
    r"$hue, $saturation": (arguments) {
      // hsl(123, var(--foo)) is valid CSS because --foo might be `10%, 20%` and
      // functions are parsed after variable substitution.
      if (arguments[0].isVar || arguments[1].isVar) {
        return _functionString('hsl', arguments);
      } else {
        throw SassScriptException(r"Missing argument $lightness.");
      }
    },
    r"$channels": (arguments) => _parseChannels('hsl', arguments[0],
        space: ColorSpace.hsl, name: 'channels')
  }),

  BuiltInCallable.overloadedFunction("hsla", {
    r"$hue, $saturation, $lightness, $alpha": (arguments) =>
        _hsl("hsla", arguments),
    r"$hue, $saturation, $lightness": (arguments) => _hsl("hsla", arguments),
    r"$hue, $saturation": (arguments) {
      if (arguments[0].isVar || arguments[1].isVar) {
        return _functionString('hsla', arguments);
      } else {
        throw SassScriptException(r"Missing argument $lightness.");
      }
    },
    r"$channels": (arguments) => _parseChannels('hsla', arguments[0],
        space: ColorSpace.hsl, name: 'channels')
  }),

  _function(
      "grayscale",
      r"$color",
      (arguments) => arguments[0] is SassNumber || arguments[0].isSpecialNumber
          // Use the native CSS `grayscale` filter function.
          ? _functionString('grayscale', arguments)
          : _grayscale(arguments[0])),

  _function("adjust-hue", r"$color, $degrees", (arguments) {
    var color = arguments[0].assertColor("color");
    var degrees = _angleValue(arguments[1], "degrees");

    var suggestedValue = SassNumber(degrees, 'deg');
    warnForDeprecation(
        "adjust-hue() is deprecated. Suggestion:\n"
        "\n"
        "color.adjust(\$color, \$hue: $suggestedValue)\n"
        "\n"
        "More info: https://sass-lang.com/d/color-functions",
        Deprecation.colorFunctions);

    return color.changeHsl(hue: color.hue + degrees);
  }),

  _function("lighten", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    var result = color.changeHsl(
        lightness: (color.lightness + amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));

    warnForDeprecation(
        "lighten() is deprecated. "
        "${_suggestScaleAndAdjust(color, amount.value, 'lightness')}\n"
        "\n"
        "More info: https://sass-lang.com/d/color-functions",
        Deprecation.colorFunctions);
    return result;
  }),

  _function("darken", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    var result = color.changeHsl(
        lightness: (color.lightness - amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));

    warnForDeprecation(
        "darken() is deprecated. "
        "${_suggestScaleAndAdjust(color, -amount.value, 'lightness')}\n"
        "\n"
        "More info: https://sass-lang.com/d/color-functions",
        Deprecation.colorFunctions);
    return result;
  }),

  BuiltInCallable.overloadedFunction("saturate", {
    r"$amount": (arguments) {
      if (arguments[0] is SassNumber || arguments[0].isSpecialNumber) {
        // Use the native CSS `saturate` filter function.
        return _functionString("saturate", arguments);
      }
      var number = arguments[0].assertNumber("amount");
      return SassString("saturate(${number.toCssString()})", quotes: false);
    },
    r"$color, $amount": (arguments) {
      var color = arguments[0].assertColor("color");
      var amount = arguments[1].assertNumber("amount");
      var result = color.changeHsl(
          saturation: (color.saturation + amount.valueInRange(0, 100, "amount"))
              .clamp(0, 100));

      warnForDeprecation(
          "saturate() is deprecated. "
          "${_suggestScaleAndAdjust(color, amount.value, 'saturation')}\n"
          "\n"
          "More info: https://sass-lang.com/d/color-functions",
          Deprecation.colorFunctions);
      return result;
    }
  }),

  _function("desaturate", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    var result = color.changeHsl(
        saturation: (color.saturation - amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));

    warnForDeprecation(
        "desaturate() is deprecated. "
        "${_suggestScaleAndAdjust(color, -amount.value, 'saturation')}\n"
        "\n"
        "More info: https://sass-lang.com/d/color-functions",
        Deprecation.colorFunctions);
    return result;
  }),

  // ### Opacity
  _function("opacify", r"$color, $amount",
      (arguments) => _opacify("opacify", arguments)),
  _function("fade-in", r"$color, $amount",
      (arguments) => _opacify("fade-in", arguments)),
  _function("transparentize", r"$color, $amount",
      (arguments) => _transparentize("transparentize", arguments)),
  _function("fade-out", r"$color, $amount",
      (arguments) => _transparentize("fade-out", arguments)),

  BuiltInCallable.overloadedFunction("alpha", {
    r"$color": (arguments) {
      var argument = arguments[0];
      if (argument is SassString &&
          !argument.hasQuotes &&
          argument.text.contains(_microsoftFilterStart)) {
        // Support the proprietary Microsoft alpha() function.
        return _functionString("alpha", arguments);
      }

      var color = argument.assertColor("color");
      return SassNumber(color.alpha);
    },
    r"$args...": (arguments) {
      var argList = arguments[0].asList;
      if (argList.isNotEmpty &&
          argList.every((argument) =>
              argument is SassString &&
              !argument.hasQuotes &&
              argument.text.contains(_microsoftFilterStart))) {
        // Support the proprietary Microsoft alpha() function.
        return _functionString("alpha", arguments);
      }

      assert(argList.length != 1);
      if (argList.isEmpty) {
        throw SassScriptException("Missing argument \$color.");
      } else {
        throw SassScriptException(
            "Only 1 argument allowed, but ${argList.length} were passed.");
      }
    }
  }),

  _function("opacity", r"$color", (arguments) {
    if (arguments[0] is SassNumber || arguments[0].isSpecialNumber) {
      // Use the native CSS `opacity` filter function.
      return _functionString("opacity", arguments);
    }

    var color = arguments[0].assertColor("color");
    return SassNumber(color.alpha);
  }),

  // ### Color Spaces

  _function(
      "color",
      r"$description",
      (arguments) =>
          _parseChannels("color", arguments[0], name: 'description')),

  _function(
      "hwb",
      r"$channels",
      (arguments) => _parseChannels("hwb", arguments[0],
          space: ColorSpace.hwb, name: 'channels')),

  _function(
      "lab",
      r"$channels",
      (arguments) => _parseChannels("lab", arguments[0],
          space: ColorSpace.lab, name: 'channels')),

  _function(
      "lch",
      r"$channels",
      (arguments) => _parseChannels("lch", arguments[0],
          space: ColorSpace.lch, name: 'channels')),

  _function(
      "oklab",
      r"$channels",
      (arguments) => _parseChannels("oklab", arguments[0],
          space: ColorSpace.oklab, name: 'channels')),

  _function(
      "oklch",
      r"$channels",
      (arguments) => _parseChannels("oklch", arguments[0],
          space: ColorSpace.oklch, name: 'channels')),

  _complement,

  // ### Miscellaneous
  _ieHexStr,
  _adjust.withName("adjust-color"),
  _scale.withName("scale-color"),
  _change.withName("change-color")
]);

/// The Sass color module.
final module = BuiltInModule("color", functions: <Callable>[
  // ### RGB
  _channelFunction("red", (color) => color.red),
  _channelFunction("green", (color) => color.green),
  _channelFunction("blue", (color) => color.blue),
  _mix,

  _function("invert", r"$color, $weight: 100%, $space: null", (arguments) {
    var result = _invert(arguments);
    if (result is SassString) {
      warnForDeprecation(
          "Passing a number (${arguments[0]}) to color.invert() is "
          "deprecated.\n"
          "\n"
          "Recommendation: $result",
          Deprecation.colorModuleCompat);
    }
    return result;
  }),

  // ### HSL
  _channelFunction("hue", (color) => color.hue, unit: 'deg'),
  _channelFunction("saturation", (color) => color.saturation, unit: '%'),
  _channelFunction("lightness", (color) => color.lightness, unit: '%'),
  _removedColorFunction("adjust-hue", "hue"),
  _removedColorFunction("lighten", "lightness"),
  _removedColorFunction("darken", "lightness", negative: true),
  _removedColorFunction("saturate", "saturation"),
  _removedColorFunction("desaturate", "saturation", negative: true),

  _function("grayscale", r"$color", (arguments) {
    if (arguments[0] is SassNumber) {
      var result = _functionString("grayscale", arguments.take(1));
      warnForDeprecation(
          "Passing a number (${arguments[0]}) to color.grayscale() is "
          "deprecated.\n"
          "\n"
          "Recommendation: $result",
          Deprecation.colorModuleCompat);
      return result;
    }

    return _grayscale(arguments[0]);
  }),

  // ### HWB
  BuiltInCallable.overloadedFunction("hwb", {
    r"$hue, $whiteness, $blackness, $alpha: 1": (arguments) => _parseChannels(
        'hwb',
        SassList([
          SassList(
              [arguments[0], arguments[1], arguments[2]], ListSeparator.space),
          arguments[3]
        ], ListSeparator.slash),
        space: ColorSpace.hwb),
    r"$channels": (arguments) => _parseChannels('hwb', arguments[0],
        space: ColorSpace.hwb, name: 'channels')
  }),

  _channelFunction("whiteness", (color) => color.whiteness, unit: '%'),
  _channelFunction("blackness", (color) => color.blackness, unit: '%'),

  // ### Opacity
  _removedColorFunction("opacify", "alpha"),
  _removedColorFunction("fade-in", "alpha"),
  _removedColorFunction("transparentize", "alpha", negative: true),
  _removedColorFunction("fade-out", "alpha", negative: true),

  BuiltInCallable.overloadedFunction("alpha", {
    r"$color": (arguments) {
      var argument = arguments[0];
      if (argument is SassString &&
          !argument.hasQuotes &&
          argument.text.contains(_microsoftFilterStart)) {
        var result = _functionString("alpha", arguments);
        warnForDeprecation(
            "Using color.alpha() for a Microsoft filter is deprecated.\n"
            "\n"
            "Recommendation: $result",
            Deprecation.colorModuleCompat);
        return result;
      }

      var color = argument.assertColor("color");
      return SassNumber(color.alpha);
    },
    r"$args...": (arguments) {
      if (arguments[0].asList.every((argument) =>
          argument is SassString &&
          !argument.hasQuotes &&
          argument.text.contains(_microsoftFilterStart))) {
        // Support the proprietary Microsoft alpha() function.
        var result = _functionString("alpha", arguments);
        warnForDeprecation(
            "Using color.alpha() for a Microsoft filter is deprecated.\n"
            "\n"
            "Recommendation: $result",
            Deprecation.colorModuleCompat);
        return result;
      }

      assert(arguments.length != 1);
      throw SassScriptException(
          "Only 1 argument allowed, but ${arguments.length} were passed.");
    }
  }),

  _function("opacity", r"$color", (arguments) {
    if (arguments[0] is SassNumber) {
      var result = _functionString("opacity", arguments);
      warnForDeprecation(
          "Passing a number (${arguments[0]} to color.opacity() is "
          "deprecated.\n"
          "\n"
          "Recommendation: $result",
          Deprecation.colorModuleCompat);
      return result;
    }

    var color = arguments[0].assertColor("color");
    return SassNumber(color.alpha);
  }),

  // ### Color Spaces
  _function(
      "space",
      r"$color",
      (arguments) => SassString(arguments.first.assertColor("color").space.name,
          quotes: false)),

  _function(
      "to-space",
      r"$color, $space",
      (arguments) =>
          _colorInSpace(arguments[0], arguments[1].assertString("space"))),

  _function("is-legacy", r"$color",
      (arguments) => SassBoolean(arguments[0].assertColor("color").isLegacy)),

  _function(
      "is-in-gamut",
      r"$color, $space: null",
      (arguments) =>
          SassBoolean(_colorInSpace(arguments[0], arguments[1]).isInGamut)),

  _function("to-gamut", r"$color, $space: null", (arguments) {
    var color = arguments[0].assertColor("color");
    var space = _spaceOrDefault(color, arguments[1], "space");
    if (!space.isBounded) return color;

    return color
        .toSpace(space == ColorSpace.hsl || space == ColorSpace.hwb
            ? ColorSpace.srgb
            : space)
        .toGamut()
        .toSpace(space);
  }),

  _function("channel", r"$color, $channel, $space: null", (arguments) {
    var color = _colorInSpace(arguments[0], arguments[2]);
    var channelName = arguments[1].assertString("channel").text.toLowerCase();
    if (channelName == "alpha") return SassNumber(color.alpha);

    var channelIndex = color.space.channels
        .indexWhere((channel) => channel.name == channelName);
    if (channelIndex == -1) {
      throw SassScriptException(
          "Color $color has no channel named $channelName.", "channel");
    }

    var channelInfo = color.space.channels[channelIndex];
    var channelValue = color.channels[channelIndex];

    return channelInfo is LinearChannel
        ? SassNumber(channelValue,
            channelInfo.min == 0 && channelInfo.max == 100 ? '%' : null)
        : SassNumber(channelValue, 'deg');
  }),

  _function("same", r"$color1, $color2", (arguments) {
    var color1 = arguments[0].assertColor('color1');
    var color2 = arguments[1].assertColor('color2');

    // Convert both colors into the same space to compare them. Usually we
    // just use color1's space, but since HSL and HWB can't represent
    // out-of-gamut colors we use RGB for all legacy color spaces.
    var targetSpace = color1.isLegacy ? ColorSpace.rgb : color1.space;
    return SassBoolean(
        color1.toSpace(targetSpace) == color2.toSpace(targetSpace));
  }),

  _function(
      "is-powerless",
      r"$color, $channel, $space: null",
      (arguments) => SassBoolean(_colorInSpace(arguments[0], arguments[2])
          .isChannelPowerless(
              arguments[1].assertString("channel").text.toLowerCase(),
              colorName: "color",
              channelName: "channel"))),

  _complement,

  // Miscellaneous
  _adjust, _scale, _change, _ieHexStr
]);

// ### RGB

final _mix = _function("mix", r"$color1, $color2, $weight: 50%, $method: null",
    (arguments) {
  var color1 = arguments[0].assertColor("color1");
  var color2 = arguments[1].assertColor("color2");
  var weight = arguments[2].assertNumber("weight");

  if (arguments[3] != sassNull) {
    return color1.interpolate(
        color2, InterpolationMethod.fromValue(arguments[3], "method"),
        weight: weight.valueInRangeWithUnit(0, 100, "weight", "%") / 100);
  }

  _checkPercent(weight, "weight");
  if (!color1.isLegacy) {
    throw SassScriptException(
        "To use color.mix() with non-legacy color $color1, you must provide a "
            "\$method.",
        "color1");
  } else if (!color2.isLegacy) {
    throw SassScriptException(
        "To use color.mix() with non-legacy color $color2, you must provide a "
            "\$method.",
        "color2");
  }

  return _mixLegacy(color1, color2, weight);
});

// ### Color Spaces

final _complement =
    _function("complement", r"$color, $space: null", (arguments) {
  var color = arguments[0].assertColor("color");
  var space = color.isLegacy && arguments[1] == sassNull
      ? ColorSpace.hsl
      : ColorSpace.fromName(
          (arguments[1].assertString("space")..assertUnquoted("space")).text,
          "space");

  if (!space.isPolar) {
    throw SassScriptException(
        "Color space $space doesn't have a hue channel.", 'space');
  }

  var inSpace = color.toSpace(space);
  return inSpace.changeChannels({'hue': inSpace.channel('hue') + 180}).toSpace(
      color.space);
});

/// The implementation of the `invert()` function.
///
/// If [global] is true, that indicates that this is being called from the
/// global `invert()` function.
Value _invert(List<Value> arguments, {bool global = false}) {
  var weightNumber = arguments[1].assertNumber("weight");
  if (arguments[0] is SassNumber || (global && arguments[0].isSpecialNumber)) {
    if (weightNumber.value != 100 || !weightNumber.hasUnit("%")) {
      throw "Only one argument may be passed to the plain-CSS invert() "
          "function.";
    }

    // Use the native CSS `invert` filter function.
    return _functionString("invert", arguments.take(1));
  }

  var color = arguments[0].assertColor("color");
  if (arguments[2] == sassNull) {
    if (!color.isLegacy) {
      throw SassScriptException(
          "To use color.invert() with non-legacy color $color, you must provide "
              "a \$space.",
          "color");
    }

    _checkPercent(weightNumber, "weight");
    var rgb = color.toSpace(ColorSpace.rgb);
    return _mixLegacy(
        SassColor.rgb(255.0 - rgb.channel0, 255.0 - rgb.channel1,
            255.0 - rgb.channel2, color.alpha),
        color,
        weightNumber);
  }

  var space = ColorSpace.fromName(
      (arguments[2].assertString('space')..assertUnquoted('space')).text,
      'space');
  var weight = weightNumber.valueInRangeWithUnit(0, 100, 'weight', '%') / 100;
  if (fuzzyEquals(weight, 0)) return color;

  var inSpace = color.toSpace(space);
  var inverted = switch (space) {
    ColorSpace.hwb => SassColor.hwb((inSpace.channel0 + 180) % 360,
        inSpace.channel2, inSpace.channel1, inSpace.alpha),
    ColorSpace.hsl => SassColor.hsl((inSpace.channel0 + 180) % 360,
        inSpace.channel1, 100 - inSpace.channel2, inSpace.alpha),
    ColorSpace.lch => SassColor.lch(100 - inSpace.channel0, inSpace.channel1,
        (inSpace.channel2 + 180) % 360, inSpace.alpha),
    ColorSpace.oklch => SassColor.oklch(1 - inSpace.channel0, inSpace.channel1,
        (inSpace.channel2 + 180) % 360, inSpace.alpha),
    ColorSpace(
      channels: [
        LinearChannel channel0,
        LinearChannel channel1,
        LinearChannel channel2
      ]
    ) =>
      SassColor.forSpaceInternal(
          space,
          _invertChannel(channel0, inSpace.channel0),
          _invertChannel(channel1, inSpace.channel1),
          _invertChannel(channel2, inSpace.channel2),
          inSpace.alpha),
    _ => throw UnsupportedError("Unknown color space $space.")
  };

  if (fuzzyEquals(weight, 1)) return inverted;
  return color.interpolate(inverted, InterpolationMethod(space),
      weight: 1 - weight);
}

/// Returns the inverse of the given [value] in a linear color channel.
double _invertChannel(LinearChannel channel, double value) =>
    channel.min < 0 ? -value : channel.max - value;

/// The implementation of the `grayscale()` function, without any logic for the
/// plain-CSS `grayscale()` syntax.
Value _grayscale(Value colorArg) {
  var color = colorArg.assertColor("color");

  if (color.isLegacy) {
    var hsl = color.toSpace(ColorSpace.hsl);
    return SassColor.hsl(hsl.channel0, 0, hsl.channel2, hsl.alpha)
        .toSpace(color.space);
  } else {
    var oklch = color.toSpace(ColorSpace.oklch);
    return SassColor.oklch(oklch.channel0, 0, oklch.channel2, oklch.alpha)
        .toSpace(color.space);
  }
}

// Miscellaneous

final _adjust = _function("adjust", r"$color, $kwargs...",
    (arguments) => _updateComponents(arguments, adjust: true));

final _scale = _function("scale", r"$color, $kwargs...",
    (arguments) => _updateComponents(arguments, scale: true));

final _change = _function("change", r"$color, $kwargs...",
    (arguments) => _updateComponents(arguments, change: true));

final _ieHexStr = _function("ie-hex-str", r"$color", (arguments) {
  var color =
      arguments[0].assertColor("color").toSpace(ColorSpace.rgb).toGamut();
  String hexString(double component) =>
      fuzzyRound(component).toRadixString(16).padLeft(2, '0').toUpperCase();
  return SassString(
      "#${hexString(color.alpha * 255)}${hexString(color.channel0)}"
      "${hexString(color.channel1)}${hexString(color.channel2)}",
      quotes: false);
});

/// Implementation for `color.change`, `color.adjust`, and `color.scale`.
///
/// Exactly one of [change], [adjust], and [scale] must be true to determine
/// which function should be executed.
SassColor _updateComponents(List<Value> arguments,
    {bool change = false, bool adjust = false, bool scale = false}) {
  assert([change, adjust, scale].where((x) => x).length == 1);

  var argumentList = arguments[1] as SassArgumentList;
  if (argumentList.asList.isNotEmpty) {
    throw SassScriptException(
        "Only one positional argument is allowed. All other arguments must "
        "be passed by name.");
  }

  var keywords = Map.of(argumentList.keywords);
  var originalColor = arguments[0].assertColor("color");
  var spaceKeyword = keywords.remove("space")?.assertString("space")
    ?..assertUnquoted("space");

  var alphaArg = keywords.remove('alpha')?.assertNumber('alpha');

  // For backwards-compatibility, we allow legacy colors to modify channels in
  // any legacy color space.
  var color =
      spaceKeyword == null && originalColor.isLegacy && keywords.isNotEmpty
          ? _sniffLegacyColorSpace(keywords).andThen(originalColor.toSpace) ??
              originalColor
          : _colorInSpace(originalColor, spaceKeyword ?? sassNull);

  var oldChannels = color.channels;
  var channelArgs = List<SassNumber?>.filled(oldChannels.length, null);
  var channelInfo = color.space.channels;
  for (var (name, value) in keywords.pairs) {
    var channelIndex = channelInfo.indexWhere((info) => name == info.name);
    if (channelIndex == -1) {
      throw SassScriptException(
          "Color space ${color.space} doesn't have a channel with this name.",
          name);
    }

    channelArgs[channelIndex] = value.assertNumber(name);
  }

  var result = change
      ? _changeColor(color, channelArgs, alphaArg)
      : scale
          ? _scaleColor(color, channelArgs, alphaArg)
          : _adjustColor(color, channelArgs, alphaArg);

  return result.toSpace(originalColor.space);
}

/// Returns a copy of [color] with its channel values replaced by those in
/// [channelArgs] and [alphaArg], if specified.
SassColor _changeColor(
    SassColor color, List<SassNumber?> channelArgs, SassNumber? alphaArg) {
  var latterUnits =
      color.space == ColorSpace.hsl || color.space == ColorSpace.hwb
          ? '%'
          : null;
  return _colorFromChannels(
      color.space,
      channelArgs[0] ?? SassNumber(color.channel0),
      channelArgs[1] ?? SassNumber(color.channel1, latterUnits),
      channelArgs[2] ?? SassNumber(color.channel2, latterUnits),
      alphaArg.andThen((alphaArg) {
            if (!alphaArg.hasUnits) {
              return alphaArg.value;
            } else if (alphaArg.hasUnit('%')) {
              return alphaArg.value / 100;
            } else {
              warnForDeprecation(
                  "\$alpha: Passing a unit other than % ($alphaArg) is "
                  "deprecated.\n"
                  "\n"
                  "To preserve current behavior: "
                  "${alphaArg.unitSuggestion('alpha')}\n"
                  "\n"
                  "See https://sass-lang.com/d/function-units",
                  Deprecation.functionUnits);
              return alphaArg.value;
            }
          }) ??
          color.alpha);
}

/// Returns a copy of [color] with its channel values scaled by the values in
/// [channelArgs] and [alphaArg], if specified.
SassColor _scaleColor(
        SassColor color, List<SassNumber?> channelArgs, SassNumber? alphaArg) =>
    SassColor.forSpaceInternal(
        color.space,
        _scaleChannel(color.space.channels[0], color.channel0, channelArgs[0]),
        _scaleChannel(color.space.channels[1], color.channel1, channelArgs[1]),
        _scaleChannel(color.space.channels[2], color.channel2, channelArgs[2]),
        _scaleChannel(ColorChannel.alpha, color.alpha, alphaArg));

/// Returns [oldValue] scaled by [factorArg] according to the definition in
/// [channel].
double _scaleChannel(
    ColorChannel channel, double oldValue, SassNumber? factorArg) {
  if (factorArg == null) return oldValue;
  if (channel is! LinearChannel) {
    throw SassScriptException("Channel isn't scalable.", channel.name);
  }

  var factor = (factorArg..assertUnit('%', channel.name))
          .valueInRangeWithUnit(-100, 100, channel.name, '%') /
      100;
  return switch (factor) {
    0 => oldValue,
    > 0 => oldValue >= channel.max
        ? oldValue
        : oldValue + (channel.max - oldValue) * factor,
    _ => oldValue <= channel.min
        ? oldValue
        : oldValue + (oldValue - channel.min) * factor
  };
}

/// Returns a copy of [color] with its channel values adjusted by the values in
/// [channelArgs] and [alphaArg], if specified.
SassColor _adjustColor(
        SassColor color, List<SassNumber?> channelArgs, SassNumber? alphaArg) =>
    SassColor.forSpaceInternal(
        color.space,
        _adjustChannel(color.space, color.space.channels[0], color.channel0,
            channelArgs[0]),
        _adjustChannel(color.space, color.space.channels[1], color.channel1,
            channelArgs[1]),
        _adjustChannel(color.space, color.space.channels[2], color.channel2,
            channelArgs[2]),
        // The color space doesn't matter for alpha, as long as it's not
        // strictly bounded.
        fuzzyClamp(
            _adjustChannel(
                ColorSpace.lab, ColorChannel.alpha, color.alpha, alphaArg),
            0,
            1));

/// Returns [oldValue] adjusted by [adjustmentArg] according to the definition
/// in [space]'s [channel].
double _adjustChannel(ColorSpace space, ColorChannel channel, double oldValue,
    SassNumber? adjustmentArg) {
  if (adjustmentArg == null) return oldValue;

  switch ((space, channel)) {
    case (ColorSpace.hsl || ColorSpace.hwb, _) when channel is! LinearChannel:
      // `_channelFromValue` expects all hue values to be compatible with `deg`,
      // but we're still in the deprecation period where we allow non-`deg`
      // values for HSL and HWB so we have to handle that ahead-of-time.
      adjustmentArg = SassNumber(_angleValue(adjustmentArg, 'hue'));

    case (ColorSpace.hsl, LinearChannel()):
      // `_channelFromValue` expects lightness/saturation to be `%`, but we're
      // still in the deprecation period where we allow non-`%` values so we
      // have to handle that ahead-of-time.
      _checkPercent(adjustmentArg, channel.name);
      adjustmentArg = SassNumber(adjustmentArg.value, '%');

    case (_, ColorChannel.alpha) when adjustmentArg.hasUnits:
      // `_channelFromValue` expects alpha to be unitless or `%`, but we're
      // still in the deprecation period where we allow other values (and
      // interpret `%` as unitless) so we have to handle that ahead-of-time.
      warnForDeprecation(
          "\$alpha: Passing a number with unit ${adjustmentArg.unitString} is "
          "deprecated.\n"
          "\n"
          "To preserve current behavior: "
          "${adjustmentArg.unitSuggestion('alpha')}\n"
          "\n"
          "More info: https://sass-lang.com/d/function-units",
          Deprecation.functionUnits);
      adjustmentArg = SassNumber(adjustmentArg.value);
  }

  var result = oldValue + _channelFromValue(channel, adjustmentArg)!;
  return space.isStrictlyBounded && channel is LinearChannel
      ? fuzzyClamp(result, channel.min, channel.max)
      : result;
}

/// Given a map of arguments passed to [_updateComponents] for a legacy color,
/// determines whether it's updating the color as RGB, HSL, or HWB.
///
/// Returns `null` if [keywords] contains no keywords for any of the legacy
/// color spaces.
ColorSpace? _sniffLegacyColorSpace(Map<String, Value> keywords) {
  for (var key in keywords.keys) {
    switch (key) {
      case "red" || "green" || "blue":
        return ColorSpace.rgb;

      case "saturation" || "lightness":
        return ColorSpace.hsl;

      case "whiteness" || "blackness":
        return ColorSpace.hwb;
    }
  }

  return keywords.containsKey("hue") ? ColorSpace.hsl : null;
}

/// Returns a string representation of [name] called with [arguments], as though
/// it were a plain CSS function.
SassString _functionString(String name, Iterable<Value> arguments) =>
    SassString(
        "$name(" +
            arguments.map((argument) => argument.toCssString()).join(', ') +
            ")",
        quotes: false);

/// Returns a [_function] that throws an error indicating that
/// `color.adjust()` should be used instead.
///
/// This prints a suggested `color.adjust()` call that passes the adjustment
/// value to [argument], with a leading minus sign if [negative] is `true`.
BuiltInCallable _removedColorFunction(String name, String argument,
        {bool negative = false}) =>
    _function(name, r"$color, $amount", (arguments) {
      throw SassScriptException(
          "The function $name() isn't in the sass:color module.\n"
          "\n"
          "Recommendation: color.adjust(${arguments[0]}, \$$argument: "
          "${negative ? '-' : ''}${arguments[1]})\n"
          "\n"
          "More info: https://sass-lang.com/documentation/functions/color#$name");
    });

/// The implementation of the three- and four-argument `rgb()` and `rgba()`
/// functions.
Value _rgb(String name, List<Value> arguments) {
  var alpha = arguments.length > 3 ? arguments[3] : null;
  if (arguments[0].isSpecialNumber ||
      arguments[1].isSpecialNumber ||
      arguments[2].isSpecialNumber ||
      (alpha?.isSpecialNumber ?? false)) {
    return _functionString(name, arguments);
  }

  return _colorFromChannels(
      ColorSpace.rgb,
      arguments[0].assertNumber("red"),
      arguments[1].assertNumber("green"),
      arguments[2].assertNumber("blue"),
      alpha == null
          ? 1.0
          : _percentageOrUnitless(alpha.assertNumber("alpha"), 1, "alpha")
              .clamp(0, 1),
      fromRgbFunction: true);
}

/// The implementation of the two-argument `rgb()` and `rgba()` functions.
Value _rgbTwoArg(String name, List<Value> arguments) {
  // rgba(var(--foo), 0.5) is valid CSS because --foo might be `123, 456, 789`
  // and functions are parsed after variable substitution.
  var first = arguments[0];
  var second = arguments[1];
  if (first.isVar || (first is! SassColor && second.isVar)) {
    return _functionString(name, arguments);
  }

  var color = first.assertColor("color");
  color.assertLegacy("color");
  color = color.toSpace(ColorSpace.rgb);
  if (second.isSpecialNumber) {
    return _functionString(name, [
      SassNumber(color.channel('red')),
      SassNumber(color.channel('green')),
      SassNumber(color.channel('blue')),
      arguments[1]
    ]);
  }

  var alpha = arguments[1].assertNumber("alpha");
  return color
      .changeAlpha(_percentageOrUnitless(alpha, 1, "alpha").clamp(0, 1));
}

/// The implementation of the three- and four-argument `hsl()` and `hsla()`
/// functions.
Value _hsl(String name, List<Value> arguments) {
  var alpha = arguments.length > 3 ? arguments[3] : null;
  if (arguments[0].isSpecialNumber ||
      arguments[1].isSpecialNumber ||
      arguments[2].isSpecialNumber ||
      (alpha?.isSpecialNumber ?? false)) {
    return _functionString(name, arguments);
  }

  return _colorFromChannels(
      ColorSpace.hsl,
      arguments[0].assertNumber("hue"),
      arguments[1].assertNumber("saturation"),
      arguments[2].assertNumber("lightness"),
      alpha == null
          ? 1.0
          : _percentageOrUnitless(alpha.assertNumber("alpha"), 1, "alpha")
              .clamp(0, 1));
}

/// Asserts that [angle] is a number and returns its value in degrees.
///
/// Prints a deprecation warning if [angle] has a non-angle unit.
double _angleValue(Value angleValue, String name) {
  var angle = angleValue.assertNumber(name);
  if (angle.compatibleWithUnit('deg')) return angle.coerceValueToUnit('deg');

  warnForDeprecation(
      "\$$name: Passing a unit other than deg ($angle) is deprecated.\n"
      "\n"
      "To preserve current behavior: ${angle.unitSuggestion(name)}\n"
      "\n"
      "See https://sass-lang.com/d/function-units",
      Deprecation.functionUnits);
  return angle.value;
}

/// Prints a deprecation warning if [number] doesn't have unit `%`.
void _checkPercent(SassNumber number, String name) {
  if (number.hasUnit('%')) return;

  warnForDeprecation(
      "\$$name: Passing a number without unit % ($number) is deprecated.\n"
      "\n"
      "To preserve current behavior: ${number.unitSuggestion(name, '%')}\n"
      "\n"
      "More info: https://sass-lang.com/d/function-units",
      Deprecation.functionUnits);
}

/// Asserts that [number] is a percentage or has no units, and normalizes the
/// value.
///
/// If [number] has no units, it's returned as-id. If it's a percentage, it's
/// scaled so that `0%` is `0` and `100%` is [max]. Otherwise, this throws a
/// [SassScriptException].
///
/// [name] is used to identify the argument in the error message.
double _percentageOrUnitless(SassNumber number, double max, [String? name]) {
  double value;
  if (!number.hasUnits) {
    value = number.value;
  } else if (number.hasUnit("%")) {
    value = max * number.value / 100;
  } else {
    throw SassScriptException(
        'Expected $number to have no units or "%".', name);
  }

  return value;
}

/// Returns [color1] and [color2], mixed together and weighted by [weight] using
/// Sass's legacy color-mixing algorithm.
SassColor _mixLegacy(SassColor color1, SassColor color2, SassNumber weight) {
  assert(color1.isLegacy, "[BUG] $color1 should be a legacy color.");
  assert(color2.isLegacy, "[BUG] $color2 should be a legacy color.");

  var rgb1 = color1.toSpace(ColorSpace.rgb);
  var rgb2 = color2.toSpace(ColorSpace.rgb);

  // This algorithm factors in both the user-provided weight (w) and the
  // difference between the alpha values of the two colors (a) to decide how
  // to perform the weighted average of the two RGB values.
  //
  // It works by first normalizing both parameters to be within [-1, 1], where
  // 1 indicates "only use color1", -1 indicates "only use color2", and all
  // values in between indicated a proportionately weighted average.
  //
  // Once we have the normalized variables w and a, we apply the formula
  // (w + a)/(1 + w*a) to get the combined weight (in [-1, 1]) of color1. This
  // formula has two especially nice properties:
  //
  //   * When either w or a are -1 or 1, the combined weight is also that
  //     number (cases where w * a == -1 are undefined, and handled as a
  //     special case).
  //
  //   * When a is 0, the combined weight is w, and vice versa.
  //
  // Finally, the weight of color1 is renormalized to be within [0, 1] and the
  // weight of color2 is given by 1 minus the weight of color1.
  var weightScale = weight.valueInRange(0, 100, "weight") / 100;
  var normalizedWeight = weightScale * 2 - 1;
  var alphaDistance = color1.alpha - color2.alpha;

  var combinedWeight1 = normalizedWeight * alphaDistance == -1
      ? normalizedWeight
      : (normalizedWeight + alphaDistance) /
          (1 + normalizedWeight * alphaDistance);
  var weight1 = (combinedWeight1 + 1) / 2;
  var weight2 = 1 - weight1;

  return SassColor.rgb(
      fuzzyRound(rgb1.channel0 * weight1 + rgb2.channel0 * weight2),
      fuzzyRound(color1.green * weight1 + color2.green * weight2),
      fuzzyRound(color1.blue * weight1 + color2.blue * weight2),
      color1.alpha * weightScale + color2.alpha * (1 - weightScale));
}

/// The definition of the `opacify()` and `fade-in()` functions.
SassColor _opacify(String name, List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");
  var result = color.changeAlpha(
      (color.alpha + amount.valueInRangeWithUnit(0, 1, "amount", ""))
          .clamp(0, 1));

  warnForDeprecation(
      "$name() is deprecated. "
      "${_suggestScaleAndAdjust(color, amount.value, 'alpha')}\n"
      "\n"
      "More info: https://sass-lang.com/d/color-functions",
      Deprecation.colorFunctions);
  return result;
}

/// The definition of the `transparentize()` and `fade-out()` functions.
SassColor _transparentize(String name, List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");
  var result = color.changeAlpha(
      (color.alpha - amount.valueInRangeWithUnit(0, 1, "amount", ""))
          .clamp(0, 1));

  warnForDeprecation(
      "$name() is deprecated. "
      "${_suggestScaleAndAdjust(color, -amount.value, 'alpha')}\n"
      "\n"
      "More info: https://sass-lang.com/d/color-functions",
      Deprecation.colorFunctions);
  return result;
}

/// Returns the [colorUntyped] as a [SassColor] in the color space specified by
/// [spaceUntyped].
///
/// Throws a [SassScriptException] if either argument isn't the expected type or
/// if [spaceUntyped] isn't the name of a color space. If [spaceUntyped] is
/// `sassNull`, it defaults to the color's existing space.
SassColor _colorInSpace(Value colorUntyped, Value spaceUntyped) {
  var color = colorUntyped.assertColor("color");
  if (spaceUntyped == sassNull) return color;

  var space = ColorSpace.fromName(
      (spaceUntyped.assertString("space")..assertUnquoted("space")).text,
      "space");
  return color.space == space ? color : color.toSpace(space);
}

/// Returns the color space named by [space], or throws a [SassScriptException]
/// if [space] isn't the name of a color space.
///
/// If [space] is `sassNull`, this returns [color]'s space instead.
///
/// If [space] came from a function argument, [name] is the argument name
/// (without the `$`). It's used for error reporting.
ColorSpace _spaceOrDefault(SassColor color, Value space, [String? name]) =>
    space == sassNull
        ? color.space
        : ColorSpace.fromName(
            (space.assertString(name)..assertUnquoted(name)).text, name);

/// Parses the color components specified by [input] into a [SassColor], or
/// returns an unquoted [SassString] representing the plain CSS function call if
/// they contain a construct that can only be resolved at browse time.
///
/// If [space] is passed, it's used as the color space to parse. Otherwise, this
/// expects the color space to be specified in [input] as for the `color()`
/// function.
///
/// Throws a [SassScriptException] if [input] is invalid. If [input] came from a
/// function argument, [name] is the argument name (without the `$`). It's used
/// for error reporting.
Value _parseChannels(String functionName, Value input,
    {ColorSpace? space, String? name}) {
  if (input.isVar) return _functionString(functionName, [input]);

  Value components;
  Value? alphaValue;
  switch (input.assertCommonListStyle(name, allowSlash: true)) {
    case [var components_, var alphaValue_]
        when input.separator == ListSeparator.slash:
      components = components_;
      alphaValue = alphaValue_;

    case var inputList when input.separator == ListSeparator.slash:
      throw SassScriptException(
          "Only 2 slash-separated elements allowed, but ${inputList.length} "
          "${pluralize('was', inputList.length, plural: 'were')} passed.");

    case [..., SassString(hasQuotes: false, :var text)] when text.contains('/'):
      return _functionString(functionName, [input]);

    case [...var initial, SassNumber(asSlash: (var before, var after))]:
      components = SassList([...initial, before], ListSeparator.space);
      alphaValue = after;

    case _:
      components = input;
  }

  List<Value> channels;
  SassString? spaceName;
  switch (components.assertCommonListStyle(name, allowSlash: false)) {
    case []:
      throw SassScriptException('Color component list may not be empty.', name);

    case _ when components.isVar:
      channels = [components];

    case [var first, ...var rest] && var componentList:
      if (space == null) {
        spaceName = first.assertString(name)..assertUnquoted(name);
        space =
            spaceName.isVar ? null : ColorSpace.fromName(spaceName.text, name);
        channels = rest;

        if (space
            case ColorSpace.rgb ||
                ColorSpace.hsl ||
                ColorSpace.hwb ||
                ColorSpace.lab ||
                ColorSpace.lch ||
                ColorSpace.oklab ||
                ColorSpace.oklch) {
          throw SassScriptException(
              "The color() function doesn't support the color space $space. Use "
              "the $space() function instead.",
              name);
        }
      } else {
        channels = componentList;
      }

      for (var channel in channels) {
        if (!channel.isSpecialNumber &&
            channel is! SassNumber &&
            !_isNone(channel)) {
          var channelName =
              space?.channels[channels.indexOf(channel)].name ?? 'channel';
          throw SassScriptException(
              'Expected $channelName $channel to be a number.', name);
        }
      }

    // dart-lang/sdk#51926
    case _:
      throw "unreachable";
  }

  if (alphaValue?.isSpecialNumber ?? false) {
    return channels.length == 3 && _specialCommaSpaces.contains(space)
        ? _functionString(functionName, [...channels, alphaValue!])
        : _functionString(functionName, [input]);
  }

  var alpha = alphaValue == null
      ? 1.0
      : _percentageOrUnitless(alphaValue.assertNumber(name), 1, 'alpha')
          .clamp(0, 1)
          .toDouble();

  // `space` will be null if either `components` or `spaceName` is a `var()`.
  // Again, we check this here rather than returning early in those cases so
  // that we can verify `alphaValue` even for colors we can't fully parse.
  if (space == null) return _functionString(functionName, [input]);
  if (channels.any((channel) => channel.isSpecialNumber)) {
    return channels.length == 3 && _specialCommaSpaces.contains(space)
        ? _functionString(
            functionName, [...channels, if (alphaValue != null) alphaValue])
        : _functionString(functionName, [input]);
  }

  if (channels.length != 3) {
    throw SassScriptException(
        'The $space color space has 3 channels but $input has '
        '${channels.length}.',
        name);
  }

  return _colorFromChannels(
      space,
      // If a channel isn't a number, it must be `none`.
      castOrNull<SassNumber>(channels[0]),
      castOrNull<SassNumber>(channels[1]),
      castOrNull<SassNumber>(channels[2]),
      alpha,
      fromRgbFunction: space == ColorSpace.rgb);
}

/// Creates a [SassColor] for the given [space] from the given channel values,
/// or throws a [SassScriptException] if the channel values are invalid.
SassColor _colorFromChannels(ColorSpace space, SassNumber? channel0,
    SassNumber? channel1, SassNumber? channel2, double alpha,
    {bool fromRgbFunction = false}) {
  switch (space) {
    case ColorSpace.hsl:
      if (channel1 != null) _checkPercent(channel1, 'saturation');
      if (channel2 != null) _checkPercent(channel2, 'lightness');
      return SassColor.hsl(
          channel0.andThen((channel0) => _angleValue(channel0, 'hue')),
          channel1?.value.clamp(0, 100).toDouble(),
          channel2?.value.clamp(0, 100).toDouble(),
          alpha);

    case ColorSpace.hwb:
      channel1?.assertUnit('%', 'whiteness');
      channel2?.assertUnit('%', 'blackness');
      var whiteness = channel1?.value.clamp(0, 100).toDouble();
      var blackness = channel2?.value.clamp(0, 100).toDouble();

      if (whiteness != null &&
          blackness != null &&
          whiteness + blackness > 100) {
        var oldWhiteness = whiteness;
        whiteness = whiteness / (whiteness + blackness) * 100;
        blackness = blackness / (oldWhiteness + blackness) * 100;
      }

      return SassColor.hwb(
          channel0.andThen((channel0) => _angleValue(channel0, 'hue')),
          whiteness,
          blackness,
          alpha);

    case ColorSpace.rgb:
      return SassColor.rgbInternal(
          _channelFromValue(space.channels[0], channel0),
          _channelFromValue(space.channels[1], channel1),
          _channelFromValue(space.channels[2], channel2),
          alpha,
          fromRgbFunction ? ColorFormat.rgbFunction : null);

    case ColorSpace.lab:
    case ColorSpace.lch:
    case ColorSpace.oklab:
    case ColorSpace.oklch:
      return SassColor.forSpaceInternal(
          space,
          _channelFromValue(space.channels[0], channel0)
              .andThen((lightness) => fuzzyClamp(lightness, 0, 100)),
          _channelFromValue(space.channels[1], channel1),
          _channelFromValue(space.channels[2], channel2),
          alpha);

    default:
      return SassColor.forSpaceInternal(
          space,
          _channelFromValue(space.channels[0], channel0),
          _channelFromValue(space.channels[1], channel1),
          _channelFromValue(space.channels[2], channel2),
          alpha);
  }
}

/// Converts a channel value from a [SassNumber] into a [double] according to
/// [channel].
double? _channelFromValue(ColorChannel channel, SassNumber? value) =>
    value.andThen((value) => switch (channel) {
          LinearChannel(requiresPercent: true) when !value.hasUnit('%') =>
            throw SassScriptException(
                'Expected $value to have unit "%".', channel.name),
          LinearChannel() =>
            _percentageOrUnitless(value, channel.max, channel.name),
          _ => value.coerceValueToUnit('deg', channel.name)
        });

/// Returns whether [value] is an unquoted string case-insensitively equal to
/// "none".
bool _isNone(Value value) =>
    value is SassString &&
    !value.hasQuotes &&
    value.text.toLowerCase() == 'none';

/// Returns the implementation of a deprecated function that returns the value
/// of the channel named [name], implemented with [getter].
///
/// If [unit] is passed, the channel is returned with that unit. The [global]
/// parameter indicates whether this was called using the legacy global syntax.
BuiltInCallable _channelFunction(
    String name, num Function(SassColor color) getter,
    {String? unit, bool global = false}) {
  return _function(name, r"$color", (arguments) {
    var result = SassNumber(getter(arguments.first.assertColor("color")), unit);

    warnForDeprecation(
        "${global ? '' : 'color.'}$name() is deprecated. Suggestion:\n"
        "\n"
        'color.channel(\$color, $name)\n'
        "\n"
        "More info: https://sass-lang.com/d/color-functions",
        Deprecation.colorFunctions);

    return result;
  });
}

/// Returns suggested translations for deprecated color modification functions
/// in terms of both `color.scale()` and `color.adjust()`.
///
/// [original] is the color that was passed in, [adjustment] is the requested
/// change, and [channelName] is the name of the modified channel.
String _suggestScaleAndAdjust(
    SassColor original, double adjustment, String channelName) {
  assert(original.isLegacy);
  var channel = channelName == 'alpha'
      ? ColorChannel.alpha
      : ColorSpace.hsl.channels
              .firstWhere((channel) => channel.name == channelName)
          as LinearChannel;

  var oldValue = channel == ColorChannel.alpha
      ? original.alpha
      : original.toSpace(ColorSpace.hsl).channel(channelName);
  var newValue = oldValue + adjustment;

  var suggestion = "Suggestion";
  if (adjustment != 0) {
    late double factor;
    if (newValue > channel.max) {
      factor = 1;
    } else if (newValue < channel.min) {
      factor = -1;
    } else if (adjustment > 0) {
      factor = adjustment / (channel.max - oldValue);
    } else {
      factor = (newValue - oldValue) / (oldValue - channel.min);
    }
    var factorNumber = SassNumber(factor * 100, '%');
    suggestion += "s:\n"
        "\n"
        "color.scale(\$color, \$$channelName: $factorNumber)\n";
  } else {
    suggestion += ":\n\n";
  }

  var difference =
      SassNumber(adjustment, channel == ColorChannel.alpha ? null : '%');
  return suggestion + "color.adjust(\$color, \$$channelName: $difference)";
}

/// Like [BuiltInCallable.function], but always sets the URL to
/// `sass:color`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:color");
