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
import '../util/nullable.dart';
import '../util/number.dart';
import '../utils.dart';
import '../value.dart';

/// A regular expression matching the beginning of a proprietary Microsoft
/// filter declaration.
final _microsoftFilterStart = RegExp(r'^[a-zA-Z]+\s*=');

/// The global definitions of Sass color functions.
final global = UnmodifiableListView([
  // ### RGB
  _red, _green, _blue, _mix,

  BuiltInCallable.overloadedFunction("rgb", {
    r"$red, $green, $blue, $alpha": (arguments) => _rgb("rgb", arguments),
    r"$red, $green, $blue": (arguments) => _rgb("rgb", arguments),
    r"$color, $alpha": (arguments) => _rgbTwoArg("rgb", arguments),
    r"$channels": (arguments) {
      var parsed = _parseChannels(
          "rgb", [r"$red", r"$green", r"$blue"], arguments.first);
      return parsed is SassString ? parsed : _rgb("rgb", parsed as List<Value>);
    }
  }),

  BuiltInCallable.overloadedFunction("rgba", {
    r"$red, $green, $blue, $alpha": (arguments) => _rgb("rgba", arguments),
    r"$red, $green, $blue": (arguments) => _rgb("rgba", arguments),
    r"$color, $alpha": (arguments) => _rgbTwoArg("rgba", arguments),
    r"$channels": (arguments) {
      var parsed = _parseChannels(
          "rgba", [r"$red", r"$green", r"$blue"], arguments.first);
      return parsed is SassString
          ? parsed
          : _rgb("rgba", parsed as List<Value>);
    }
  }),

  _function("invert", r"$color, $weight: 100%", (arguments) {
    var weight = arguments[1].assertNumber("weight");
    if (arguments[0] is SassNumber || arguments[0].isSpecialNumber) {
      if (weight.value != 100 || !weight.hasUnit("%")) {
        throw "Only one argument may be passed to the plain-CSS invert() "
            "function.";
      }

      // Use the native CSS `invert` filter function.
      return _functionString("invert", arguments.take(1));
    }

    var color = arguments[0].assertColor("color");
    var inverse = color.changeRgb(
        red: 255 - color.red, green: 255 - color.green, blue: 255 - color.blue);

    return _mixColors(inverse, color, weight);
  }),

  // ### HSL
  _hue, _saturation, _lightness, _complement,

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
    r"$channels": (arguments) {
      var parsed = _parseChannels(
          "hsl", [r"$hue", r"$saturation", r"$lightness"], arguments.first);
      return parsed is SassString ? parsed : _hsl("hsl", parsed as List<Value>);
    }
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
    r"$channels": (arguments) {
      var parsed = _parseChannels(
          "hsla", [r"$hue", r"$saturation", r"$lightness"], arguments.first);
      return parsed is SassString
          ? parsed
          : _hsl("hsla", parsed as List<Value>);
    }
  }),

  _function("grayscale", r"$color", (arguments) {
    if (arguments[0] is SassNumber || arguments[0].isSpecialNumber) {
      // Use the native CSS `grayscale` filter function.
      return _functionString('grayscale', arguments);
    }

    var color = arguments[0].assertColor("color");
    return color.changeHsl(saturation: 0);
  }),

  _function("adjust-hue", r"$color, $degrees", (arguments) {
    var color = arguments[0].assertColor("color");
    var degrees = _angleValue(arguments[1], "degrees");
    return color.changeHsl(hue: color.hue + degrees);
  }),

  _function("lighten", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        lightness: (color.lightness + amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));
  }),

  _function("darken", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        lightness: (color.lightness - amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));
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
      return color.changeHsl(
          saturation: (color.saturation + amount.valueInRange(0, 100, "amount"))
              .clamp(0, 100));
    }
  }),

  _function("desaturate", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        saturation: (color.saturation - amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));
  }),

  // ### Opacity
  _function("opacify", r"$color, $amount", _opacify),
  _function("fade-in", r"$color, $amount", _opacify),
  _function("transparentize", r"$color, $amount", _transparentize),
  _function("fade-out", r"$color, $amount", _transparentize),

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

  // ### Miscellaneous
  _ieHexStr,
  _adjust.withName("adjust-color"),
  _scale.withName("scale-color"),
  _change.withName("change-color")
]);

/// The Sass color module.
final module = BuiltInModule("color", functions: <Callable>[
  // ### RGB
  _red, _green, _blue, _mix,

  _function("invert", r"$color, $weight: 100%", (arguments) {
    var weight = arguments[1].assertNumber("weight");
    if (arguments[0] is SassNumber) {
      if (weight.value != 100 || !weight.hasUnit("%")) {
        throw "Only one argument may be passed to the plain-CSS invert() "
            "function.";
      }

      var result = _functionString("invert", arguments.take(1));
      warnForDeprecation(
          "Passing a number (${arguments[0]}) to color.invert() is "
          "deprecated.\n"
          "\n"
          "Recommendation: $result",
          Deprecation.colorModuleCompat);
      return result;
    }

    var color = arguments[0].assertColor("color");
    var inverse = color.changeRgb(
        red: 255 - color.red, green: 255 - color.green, blue: 255 - color.blue);

    return _mixColors(inverse, color, weight);
  }),

  // ### HSL
  _hue, _saturation, _lightness, _complement,
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

    var color = arguments[0].assertColor("color");
    return color.changeHsl(saturation: 0);
  }),

  // ### HWB
  BuiltInCallable.overloadedFunction("hwb", {
    r"$hue, $whiteness, $blackness, $alpha: 1": (arguments) => _hwb(arguments),
    r"$channels": (arguments) {
      var parsed = _parseChannels(
          "hwb", [r"$hue", r"$whiteness", r"$blackness"], arguments.first);

      // `hwb()` doesn't (currently) support special number or variable strings.
      if (parsed is SassString) {
        throw SassScriptException('Expected numeric channels, got "$parsed".');
      } else {
        return _hwb(parsed as List<Value>);
      }
    }
  }),

  _function(
      "whiteness",
      r"$color",
      (arguments) =>
          SassNumber(arguments.first.assertColor("color").whiteness, "%")),

  _function(
      "blackness",
      r"$color",
      (arguments) =>
          SassNumber(arguments.first.assertColor("color").blackness, "%")),

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

  // Miscellaneous
  _adjust, _scale, _change, _ieHexStr
]);

// ### RGB

final _red = _function("red", r"$color", (arguments) {
  return SassNumber(arguments.first.assertColor("color").red);
});

final _green = _function("green", r"$color", (arguments) {
  return SassNumber(arguments.first.assertColor("color").green);
});

final _blue = _function("blue", r"$color", (arguments) {
  return SassNumber(arguments.first.assertColor("color").blue);
});

final _mix = _function("mix", r"$color1, $color2, $weight: 50%", (arguments) {
  var color1 = arguments[0].assertColor("color1");
  var color2 = arguments[1].assertColor("color2");
  var weight = arguments[2].assertNumber("weight");
  return _mixColors(color1, color2, weight);
});

// ### HSL

final _hue = _function("hue", r"$color",
    (arguments) => SassNumber(arguments.first.assertColor("color").hue, "deg"));

final _saturation = _function(
    "saturation",
    r"$color",
    (arguments) =>
        SassNumber(arguments.first.assertColor("color").saturation, "%"));

final _lightness = _function(
    "lightness",
    r"$color",
    (arguments) =>
        SassNumber(arguments.first.assertColor("color").lightness, "%"));

final _complement = _function("complement", r"$color", (arguments) {
  var color = arguments[0].assertColor("color");
  return color.changeHsl(hue: color.hue + 180);
});

// Miscellaneous

final _adjust = _function("adjust", r"$color, $kwargs...",
    (arguments) => _updateComponents(arguments, adjust: true));

final _scale = _function("scale", r"$color, $kwargs...",
    (arguments) => _updateComponents(arguments, scale: true));

final _change = _function("change", r"$color, $kwargs...",
    (arguments) => _updateComponents(arguments, change: true));

final _ieHexStr = _function("ie-hex-str", r"$color", (arguments) {
  var color = arguments[0].assertColor("color");
  String hexString(int component) =>
      component.toRadixString(16).padLeft(2, '0').toUpperCase();
  return SassString(
      "#${hexString(fuzzyRound(color.alpha * 255))}${hexString(color.red)}"
      "${hexString(color.green)}${hexString(color.blue)}",
      quotes: false);
});

/// Implementation for `color.change`, `color.adjust`, and `color.scale`.
///
/// Exactly one of [change], [adjust], and [scale] must be true to determine
/// which function should be executed.
SassColor _updateComponents(List<Value> arguments,
    {bool change = false, bool adjust = false, bool scale = false}) {
  assert([change, adjust, scale].where((x) => x).length == 1);

  var color = arguments[0].assertColor("color");
  var argumentList = arguments[1] as SassArgumentList;
  if (argumentList.asList.isNotEmpty) {
    throw SassScriptException(
        "Only one positional argument is allowed. All other arguments must "
        "be passed by name.");
  }

  var keywords = Map.of(argumentList.keywords);

  /// Gets and validates the parameter with [name] from keywords.
  ///
  /// [max] should be 255 for RGB channels, 1 for the alpha channel, and 100
  /// for saturation, lightness, whiteness, and blackness.
  double? getParam(String name, num max,
      {bool checkPercent = false,
      bool assertPercent = false,
      bool checkUnitless = false}) {
    var number = keywords.remove(name)?.assertNumber(name);
    if (number == null) return null;
    if (!scale && checkUnitless) {
      if (number.hasUnits) {
        warnForDeprecation(
            "\$$name: Passing a number with unit ${number.unitString} is "
            "deprecated.\n"
            "\n"
            "To preserve current behavior: ${number.unitSuggestion(name)}\n"
            "\n"
            "More info: https://sass-lang.com/d/function-units",
            Deprecation.functionUnits);
      }
    }
    if (!scale && checkPercent) _checkPercent(number, name);
    if (scale || assertPercent) number.assertUnit("%", name);
    if (scale) max = 100;
    return scale || assertPercent
        ? number.valueInRange(change ? 0 : -max, max, name)
        : number.valueInRangeWithUnit(
            change ? 0 : -max, max, name, checkPercent ? '%' : '');
  }

  var alpha = getParam("alpha", 1, checkUnitless: true);
  var red = getParam("red", 255);
  var green = getParam("green", 255);
  var blue = getParam("blue", 255);

  var hue = scale
      ? null
      : keywords.remove("hue").andThen((hue) => _angleValue(hue, "hue"));

  var saturation = getParam("saturation", 100, checkPercent: true);
  var lightness = getParam("lightness", 100, checkPercent: true);
  var whiteness = getParam("whiteness", 100, assertPercent: true);
  var blackness = getParam("blackness", 100, assertPercent: true);

  if (keywords.isNotEmpty) {
    throw SassScriptException(
        "No ${pluralize('argument', keywords.length)} named "
        "${toSentence(keywords.keys.map((name) => '\$$name'), 'or')}.");
  }

  var hasRgb = red != null || green != null || blue != null;
  var hasSL = saturation != null || lightness != null;
  var hasWB = whiteness != null || blackness != null;

  if (hasRgb && (hasSL || hasWB || hue != null)) {
    throw SassScriptException("RGB parameters may not be passed along with "
        "${hasWB ? 'HWB' : 'HSL'} parameters.");
  }

  if (hasSL && hasWB) {
    throw SassScriptException(
        "HSL parameters may not be passed along with HWB parameters.");
  }

  /// Updates [current] based on [param], clamped within [max].
  double updateValue(double current, double? param, num max) {
    if (param == null) return current;
    if (change) return param;
    if (adjust) return (current + param).clamp(0, max).toDouble();
    return current + (param > 0 ? max - current : current) * (param / 100);
  }

  int updateRgb(int current, double? param) =>
      fuzzyRound(updateValue(current.toDouble(), param, 255));

  if (hasRgb) {
    return color.changeRgb(
        red: updateRgb(color.red, red),
        green: updateRgb(color.green, green),
        blue: updateRgb(color.blue, blue),
        alpha: updateValue(color.alpha, alpha, 1));
  } else if (hasWB) {
    return color.changeHwb(
        hue: change ? hue : color.hue + (hue ?? 0),
        whiteness: updateValue(color.whiteness, whiteness, 100),
        blackness: updateValue(color.blackness, blackness, 100),
        alpha: updateValue(color.alpha, alpha, 1));
  } else if (hue != null || hasSL) {
    return color.changeHsl(
        hue: change ? hue : color.hue + (hue ?? 0),
        saturation: updateValue(color.saturation, saturation, 100),
        lightness: updateValue(color.lightness, lightness, 100),
        alpha: updateValue(color.alpha, alpha, 1));
  } else if (alpha != null) {
    return color.changeAlpha(updateValue(color.alpha, alpha, 1));
  } else {
    return color;
  }
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

Value _rgb(String name, List<Value> arguments) {
  var alpha = arguments.length > 3 ? arguments[3] : null;
  if (arguments[0].isSpecialNumber ||
      arguments[1].isSpecialNumber ||
      arguments[2].isSpecialNumber ||
      (alpha?.isSpecialNumber ?? false)) {
    return _functionString(name, arguments);
  }

  var red = arguments[0].assertNumber("red");
  var green = arguments[1].assertNumber("green");
  var blue = arguments[2].assertNumber("blue");

  return SassColor.rgbInternal(
      fuzzyRound(_percentageOrUnitless(red, 255, "red")),
      fuzzyRound(_percentageOrUnitless(green, 255, "green")),
      fuzzyRound(_percentageOrUnitless(blue, 255, "blue")),
      alpha.andThen((alpha) =>
              _percentageOrUnitless(alpha.assertNumber("alpha"), 1, "alpha")) ??
          1,
      ColorFormat.rgbFunction);
}

Value _rgbTwoArg(String name, List<Value> arguments) {
  // rgba(var(--foo), 0.5) is valid CSS because --foo might be `123, 456, 789`
  // and functions are parsed after variable substitution.
  if (arguments[0].isVar ||
      (arguments[0] is! SassColor && arguments[1].isVar)) {
    return _functionString(name, arguments);
  } else if (arguments[1].isSpecialNumber) {
    var color = arguments[0].assertColor("color");
    return SassString(
        "$name(${color.red}, ${color.green}, ${color.blue}, "
        "${arguments[1].toCssString()})",
        quotes: false);
  }

  var color = arguments[0].assertColor("color");
  var alpha = arguments[1].assertNumber("alpha");
  return color.changeAlpha(_percentageOrUnitless(alpha, 1, "alpha"));
}

Value _hsl(String name, List<Value> arguments) {
  var alpha = arguments.length > 3 ? arguments[3] : null;
  if (arguments[0].isSpecialNumber ||
      arguments[1].isSpecialNumber ||
      arguments[2].isSpecialNumber ||
      (alpha?.isSpecialNumber ?? false)) {
    return _functionString(name, arguments);
  }

  var hue = _angleValue(arguments[0], "hue");
  var saturation = arguments[1].assertNumber("saturation");
  var lightness = arguments[2].assertNumber("lightness");

  _checkPercent(saturation, "saturation");
  _checkPercent(lightness, "lightness");

  return SassColor.hslInternal(
      hue,
      saturation.value.clamp(0, 100),
      lightness.value.clamp(0, 100),
      alpha.andThen((alpha) =>
              _percentageOrUnitless(alpha.assertNumber("alpha"), 1, "alpha")) ??
          1,
      ColorFormat.hslFunction);
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

/// Create an HWB color from the given [arguments].
Value _hwb(List<Value> arguments) {
  var alpha = arguments.length > 3 ? arguments[3] : null;
  var hue = _angleValue(arguments[0], "hue");
  var whiteness = arguments[1].assertNumber("whiteness");
  var blackness = arguments[2].assertNumber("blackness");

  whiteness.assertUnit("%", "whiteness");
  blackness.assertUnit("%", "blackness");

  return SassColor.hwb(
      hue,
      whiteness.valueInRange(0, 100, "whiteness"),
      blackness.valueInRange(0, 100, "blackness"),
      alpha.andThen((alpha) =>
              _percentageOrUnitless(alpha.assertNumber("alpha"), 1, "alpha")) ??
          1);
}

Object /* SassString | List<Value> */ _parseChannels(
    String name, List<String> argumentNames, Value channels) {
  if (channels.isVar) return _functionString(name, [channels]);

  var originalChannels = channels;
  Value? alphaFromSlashList;
  if (channels.separator == ListSeparator.slash) {
    var list = channels.asList;
    if (list.length != 2) {
      throw SassScriptException(
          "Only 2 slash-separated elements allowed, but ${list.length} "
          "${pluralize('was', list.length, plural: 'were')} passed.");
    }

    channels = list[0];

    alphaFromSlashList = list[1];
    if (!alphaFromSlashList.isSpecialNumber) {
      alphaFromSlashList.assertNumber("alpha");
    }
    if (list[0].isVar) return _functionString(name, [originalChannels]);
  }

  var isCommaSeparated = channels.separator == ListSeparator.comma;
  var isBracketed = channels.hasBrackets;
  if (isCommaSeparated || isBracketed) {
    var buffer = StringBuffer(r"$channels must be");
    if (isBracketed) buffer.write(" an unbracketed");
    if (isCommaSeparated) {
      buffer.write(isBracketed ? "," : " a");
      buffer.write(" space-separated");
    }
    buffer.write(" list.");
    throw SassScriptException(buffer.toString());
  }

  var list = channels.asList;
  if (list case [SassString(:var text, hasQuotes: false), _, ...]
      when equalsIgnoreCase(text, "from")) {
    return _functionString(name, [originalChannels]);
  }

  if (list.length > 3) {
    throw SassScriptException("Only 3 elements allowed, but ${list.length} "
        "were passed.");
  } else if (list.length < 3) {
    if (list.any((value) => value.isVar) ||
        (list.isNotEmpty && _isVarSlash(list.last))) {
      return _functionString(name, [originalChannels]);
    } else {
      var argument = argumentNames[list.length];
      throw SassScriptException("Missing element $argument.");
    }
  }

  if (alphaFromSlashList != null) return [...list, alphaFromSlashList];

  return switch (list[2]) {
    SassNumber(asSlash: (var channel3, var alpha)) => [
        list[0],
        list[1],
        channel3,
        alpha
      ],
    SassString(hasQuotes: false, :var text) when text.contains("/") =>
      _functionString(name, [channels]),
    _ => list
  };
}

/// Returns whether [value] is an unquoted string that start with `var(` and
/// contains `/`.
bool _isVarSlash(Value value) =>
    value is SassString &&
    value.hasQuotes &&
    startsWithIgnoreCase(value.text, "var(") &&
    value.text.contains("/");

/// Asserts that [number] is a percentage or has no units, and normalizes the
/// value.
///
/// If [number] has no units, its value is clamped to be greater than `0` or
/// less than [max] and returned. If [number] is a percentage, it's scaled to be
/// within `0` and [max]. Otherwise, this throws a [SassScriptException].
///
/// [name] is used to identify the argument in the error message.
double _percentageOrUnitless(SassNumber number, num max, String name) {
  double value;
  if (!number.hasUnits) {
    value = number.value;
  } else if (number.hasUnit("%")) {
    value = max * number.value / 100;
  } else {
    throw SassScriptException(
        '\$$name: Expected $number to have unit "%" or no units.');
  }

  return value.clamp(0, max).toDouble();
}

/// Returns [color1] and [color2], mixed together and weighted by [weight].
SassColor _mixColors(SassColor color1, SassColor color2, SassNumber weight) {
  _checkPercent(weight, 'weight');

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
      fuzzyRound(color1.red * weight1 + color2.red * weight2),
      fuzzyRound(color1.green * weight1 + color2.green * weight2),
      fuzzyRound(color1.blue * weight1 + color2.blue * weight2),
      color1.alpha * weightScale + color2.alpha * (1 - weightScale));
}

/// The definition of the `opacify()` and `fade-in()` functions.
SassColor _opacify(List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");

  return color.changeAlpha(
      (color.alpha + amount.valueInRangeWithUnit(0, 1, "amount", ""))
          .clamp(0, 1));
}

/// The definition of the `transparentize()` and `fade-out()` functions.
SassColor _transparentize(List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");

  return color.changeAlpha(
      (color.alpha - amount.valueInRangeWithUnit(0, 1, "amount", ""))
          .clamp(0, 1));
}

/// Like [BuiltInCallable.function], but always sets the URL to
/// `sass:color`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:color");
