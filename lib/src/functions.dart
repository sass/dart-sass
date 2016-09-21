// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'callable.dart';
import 'environment.dart';
import 'exception.dart';
import 'utils.dart';
import 'value.dart';

final _microsoftFilterStart = new RegExp(r'^[a-zA-Z]+\s*=');

void defineCoreFunctions(Environment environment) {
  // ## RGB

  environment.setFunction(
      new BuiltInCallable("rgb", r"$red, $green, $blue", (arguments) {
    // TODO: support calc strings
    var red = arguments[0].assertNumber("red");
    var green = arguments[1].assertNumber("green");
    var blue = arguments[2].assertNumber("blue");

    return new SassColor.rgb(
        fuzzyRound(_percentageOrUnitless(red, 255, "red")),
        fuzzyRound(_percentageOrUnitless(green, 255, "green")),
        fuzzyRound(_percentageOrUnitless(blue, 255, "blue")));
  }));

  environment.setFunction(new BuiltInCallable.overloaded("rgba", [
    r"$red, $green, $blue, $alpha",
    r"$color, $alpha",
  ], [
    (arguments) {
      // TODO: support calc strings
      var red = arguments[0].assertNumber("red");
      var green = arguments[1].assertNumber("green");
      var blue = arguments[2].assertNumber("blue");
      var alpha = arguments[3].assertNumber("alpha");

      return new SassColor.rgb(
          _percentageOrUnitless(red, 255, "red").round(),
          _percentageOrUnitless(green, 255, "green").round(),
          _percentageOrUnitless(blue, 255, "blue").round(),
          _percentageOrUnitless(alpha, 1, "alpha"));
    },
    (arguments) {
      var color = arguments[0].assertColor("color");
      var alpha = arguments[0].assertNumber("alpha");
      return color.changeAlpha(_percentageOrUnitless(alpha, 1, "alpha"));
    }
  ]));

  environment.setFunction(new BuiltInCallable("red", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").red);
  }));

  environment.setFunction(new BuiltInCallable("green", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").green);
  }));

  environment.setFunction(new BuiltInCallable("blue", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").blue);
  }));

  environment.setFunction(new BuiltInCallable(
      "mix", r"$color1, $color2, $weight: 50%", (arguments) {
    var color1 = arguments[0].assertColor("color1");
    var color2 = arguments[1].assertColor("color2");
    var weight = arguments[2].assertNumber("weight");
    return _mix(color1, color2, weight);
  }));

  // ## HSL

  environment.setFunction(
      new BuiltInCallable("hsl", r"$hue, $saturation, $lightness", (arguments) {
    // TODO: support calc strings
    var hue = arguments[0].assertNumber("hue");
    var saturation = arguments[1].assertNumber("saturation");
    var lightness = arguments[2].assertNumber("lightness");

    return new SassColor.hsl(hue.value, saturation.value, lightness.value);
  }));

  environment.setFunction(new BuiltInCallable(
      "hsla", r"$hue, $saturation, $lightness, $alpha", (arguments) {
    // TODO: support calc strings
    var hue = arguments[0].assertNumber("hue");
    var saturation = arguments[1].assertNumber("saturation");
    var lightness = arguments[2].assertNumber("lightness");
    var alpha = arguments[3].assertNumber("alpha");

    return new SassColor.hsl(hue.value, saturation.value, lightness.value,
        _percentageOrUnitless(alpha, 1, "alpha"));
  }));

  environment.setFunction(new BuiltInCallable("hue", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").hue, "deg");
  }));

  environment
      .setFunction(new BuiltInCallable("saturation", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").saturation, "%");
  }));

  environment
      .setFunction(new BuiltInCallable("lightness", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").lightness, "%");
  }));

  environment.setFunction(
      new BuiltInCallable("adjust-hue", r"$color, $degrees", (arguments) {
    var color = arguments[0].assertColor("color");
    var degrees = arguments[1].assertNumber("degrees");
    return color.changeHsl(hue: color.hue + degrees.value);
  }));

  environment.setFunction(
      new BuiltInCallable("lighten", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        lightness: color.lightness + amount.valueInRange(0, 100, "amount"));
  }));

  environment.setFunction(
      new BuiltInCallable("darken", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        lightness: color.lightness - amount.valueInRange(0, 100, "amount"));
  }));

  environment.setFunction(
      new BuiltInCallable("saturate", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        saturation: color.saturation + amount.valueInRange(0, 100, "amount"));
  }));

  environment.setFunction(
      new BuiltInCallable("desaturate", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        saturation: color.saturation - amount.valueInRange(0, 100, "amount"));
  }));

  environment
      .setFunction(new BuiltInCallable("grayscale", r"$color", (arguments) {
    if (arguments[0] is SassNumber) {
      return new SassString("grayscale(${arguments[0]})");
    }

    var color = arguments[0].assertColor("color");
    return color.changeHsl(saturation: 0);
  }));

  environment
      .setFunction(new BuiltInCallable("complement", r"$color", (arguments) {
    var color = arguments[0].assertColor("color");
    return color.changeHsl(hue: color.hue + 180);
  }));

  environment.setFunction(
      new BuiltInCallable("invert", r"$color, $weight: 50%", (arguments) {
    if (arguments[0] is SassNumber) {
      // TODO: find some way of ensuring this is stringified using the right
      // options. We may need to resort to zones.
      return new SassString("invert(${arguments[0]})");
    }

    var color = arguments[0].assertColor("color");
    var weight = arguments[1].assertNumber("weight");
    var inverse = color.changeRgb(
        red: 255 - color.red, green: 255 - color.green, blue: 255 - color.blue);
    if (weight.value == 50) return inverse;

    return _mix(color, inverse, weight);
  }));

  // ## Opacity

  environment.setFunction(new BuiltInCallable.overloaded("alpha", [
    r"$color",
    r"$args..."
  ], [
    (arguments) {
      var argument = arguments[0];
      if (argument is SassString &&
          !argument.hasQuotes &&
          argument.text.contains(_microsoftFilterStart)) {
        // Suport the proprietary Microsoft alpha() function.
        return new SassString("alpha($argument)");
      }

      var color = argument.assertColor("color");
      return new SassNumber(color.alpha);
    },
    (arguments) {
      if (arguments.every((argument) =>
          argument is SassString &&
          !argument.hasQuotes &&
          argument.text.contains(_microsoftFilterStart))) {
        // Suport the proprietary Microsoft alpha() function.
        return new SassString("alpha(${arguments.join(', ')})");
      }

      assert(arguments.length != 1);
      throw new InternalException(
          "Only 1 argument allowed, but ${arguments.length} were passed.");
    }
  ]));

  environment
      .setFunction(new BuiltInCallable("opacity", r"$color", (arguments) {
    if (arguments[0] is SassNumber) {
      return new SassString("opacity(${arguments[0]})");
    }

    var color = arguments[0].assertColor("color");
    return new SassNumber(color.alpha);
  }));

  environment.setFunction(new BuiltInCallable("opacify", r"$color", _opacify));
  environment.setFunction(new BuiltInCallable("fade-in", r"$color", _opacify));
  environment.setFunction(
      new BuiltInCallable("transparentize", r"$color", _transparentize));
  environment
      .setFunction(new BuiltInCallable("fade-out", r"$color", _transparentize));

  // ## Miscellaneous Color

  environment.setFunction(
      new BuiltInCallable("adjust-color", r"$color, $kwargs...", (arguments) {
    var color = arguments[0].assertColor("color");
    var argumentList = arguments[1] as SassArgumentList;
    if (argumentList.contents.isNotEmpty) {
      throw new InternalException(
          "Only only positional argument is allowed. All other arguments must "
          "be passed by name.");
    }

    var keywords = normalizedMap/*<Value>*/()..addAll(argumentList.keywords);
    getInRange(String name, num min, num max) =>
        keywords.remove(name)?.assertNumber(name)?.valueInRange(min, max, name);

    var red = getInRange("red", -255, 255);
    var green = getInRange("green", -255, 255);
    var blue = getInRange("blue", -255, 255);
    var hue = keywords.remove("hue")?.assertNumber("hue")?.value;
    var saturation = getInRange("saturation", -100, 100);
    var lightness = getInRange("lightness", -100, 100);
    var alpha = getInRange("alpha", -1, 1);

    if (keywords.isNotEmpty) {
      throw new InternalException(
          "No ${pluralize('argument', keywords.length)} named "
          "${toSentence(keywords.keys.map((name) => "\$$name"), 'or')}.");
    }

    var hasRgb = red != null || green != null || blue != null;
    var hasHsl = hue != null || saturation != null || lightness != null;
    if (hasRgb) {
      if (hasHsl) {
        throw new InternalException(
            "RGB parameters may not be passed along with HSL parameters.");
      }

      return color.changeRgb(
          red: color.red + (red ?? 0),
          green: color.green + (green ?? 0),
          blue: color.blue + (blue ?? 0),
          alpha: color.alpha + (alpha ?? 0));
    } else if (hasHsl) {
      return color.changeHsl(
          hue: color.hue + (hue ?? 0),
          saturation: color.saturation + (saturation ?? 0),
          lightness: color.lightness + (lightness ?? 0),
          alpha: color.alpha + (alpha ?? 0));
    } else {
      return color.changeAlpha(color.alpha + (alpha ?? 0));
    }
  }));

  environment.setFunction(
      new BuiltInCallable("scale-color", r"$color, $kwargs...", (arguments) {
    var color = arguments[0].assertColor("color");
    var argumentList = arguments[1] as SassArgumentList;
    if (argumentList.contents.isNotEmpty) {
      throw new InternalException(
          "Only only positional argument is allowed. All other arguments must "
          "be passed by name.");
    }

    var keywords = normalizedMap/*<Value>*/()..addAll(argumentList.keywords);
    getScale(String name) {
      var value = keywords.remove(name);
      if (value == null) return null;
      var number = value.assertNumber(name);
      number.assertUnit("%", name);
      return number.valueInRange(-100, 100, name) / 100;
    }

    scaleValue(num current, num scale, num max) {
      if (scale == null) return current;
      return current + (scale > 0 ? max - current : current) * scale;
    }

    var red = getScale("red");
    var green = getScale("green");
    var blue = getScale("blue");
    var saturation = getScale("saturation");
    var lightness = getScale("lightness");
    var alpha = getScale("alpha");

    if (keywords.isNotEmpty) {
      throw new InternalException(
          "No ${pluralize('argument', keywords.length)} named "
          "${toSentence(keywords.keys.map((name) => "\$$name"), 'or')}.");
    }

    var hasRgb = red != null || green != null || blue != null;
    var hasHsl = saturation != null || lightness != null;
    if (hasRgb) {
      if (hasHsl) {
        throw new InternalException(
            "RGB parameters may not be passed along with HSL parameters.");
      }

      return color.changeRgb(
          red: scaleValue(color.red, red, 255),
          green: scaleValue(color.green, green, 255),
          blue: scaleValue(color.blue, blue, 255),
          alpha: scaleValue(color.alpha, alpha, 1));
    } else if (hasHsl) {
      return color.changeHsl(
          saturation: scaleValue(color.saturation, saturation, 100),
          lightness: scaleValue(color.lightness, lightness, 100),
          alpha: scaleValue(color.alpha, alpha, 1));
    } else {
      return color.changeAlpha(scaleValue(color.alpha, alpha, 1));
    }
  }));

  environment.setFunction(
      new BuiltInCallable("change-color", r"$color, $kwargs...", (arguments) {
    var color = arguments[0].assertColor("color");
    var argumentList = arguments[1] as SassArgumentList;
    if (argumentList.contents.isNotEmpty) {
      throw new InternalException(
          "Only only positional argument is allowed. All other arguments must "
          "be passed by name.");
    }

    var keywords = normalizedMap/*<Value>*/()..addAll(argumentList.keywords);
    getInRange(String name, num min, num max) =>
        keywords.remove(name)?.assertNumber(name)?.valueInRange(min, max, name);

    var red = getInRange("red", 0, 255);
    var green = getInRange("green", 0, 255);
    var blue = getInRange("blue", 0, 255);
    var hue = keywords.remove("hue")?.assertNumber("hue")?.value;
    var saturation = getInRange("saturation", 0, 100);
    var lightness = getInRange("lightness", 0, 100);
    var alpha = getInRange("alpha", 0, 1);

    if (keywords.isNotEmpty) {
      throw new InternalException(
          "No ${pluralize('argument', keywords.length)} named "
          "${toSentence(keywords.keys.map((name) => "\$$name"), 'or')}.");
    }

    var hasRgb = red != null || green != null || blue != null;
    var hasHsl = saturation != null || lightness != null;
    if (hasRgb) {
      if (hasHsl) {
        throw new InternalException(
            "RGB parameters may not be passed along with HSL parameters.");
      }

      return color.changeRgb(red: red, green: green, blue: blue, alpha: alpha);
    } else if (hasHsl) {
      return color.changeHsl(
          hue: hue, saturation: saturation, lightness: lightness, alpha: alpha);
    } else {
      return color.changeAlpha(alpha);
    }
  }));

  environment
      .setFunction(new BuiltInCallable("ie-hex-str", r"$color", (arguments) {
    var color = arguments[0].assertColor("color");
    hexString(int component) =>
        component.toRadixString(16).padLeft(2, '0').toUpperCase();
    return new SassString(
        "#${hexString(fuzzyRound(color.alpha * 255))}${hexString(color.red)}"
        "${hexString(color.green)}${hexString(color.blue)}");
  }));

  // ## String

  environment
      .setFunction(new BuiltInCallable("unquote", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    if (!string.hasQuotes) return string;
    return new SassString(string.text);
  }));

  environment.setFunction(new BuiltInCallable("quote", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    if (string.hasQuotes) return string;
    return new SassString(string.text, quotes: true);
  }));

  environment
      .setFunction(new BuiltInCallable("str-length", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    return new SassNumber(string.text.runes.length);
  }));

  // ## Introspection

  environment.setFunction(new BuiltInCallable("inspect", r"$value",
      (arguments) => new SassString(arguments.first.toString())));
}

num _percentageOrUnitless(SassNumber number, num max, String name) {
  num value;
  if (!number.hasUnits) {
    value = number.value;
  } else if (number.hasUnit("%")) {
    value = max * number.value / 100;
  } else {
    throw new InternalException(
        '\$$name: Expected $number to have no units or "%".');
  }

  return value.clamp(0, max);
}

SassColor _mix(SassColor color1, SassColor color2, SassNumber weight) {
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

  return new SassColor.rgb(
      (color1.red * weight1 + color2.red * weight2).round(),
      (color1.green * weight1 + color2.green * weight2).round(),
      (color1.blue * weight1 + color2.blue * weight2).round(),
      color1.alpha * weightScale + color2.alpha * (1 - weightScale));
}

SassColor _opacify(List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");

  return color.changeAlpha(color.alpha + amount.valueInRange(0, 1, "amount"));
}

SassColor _transparentize(List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");

  return color.changeAlpha(color.alpha - amount.valueInRange(0, 1, "amount"));
}
