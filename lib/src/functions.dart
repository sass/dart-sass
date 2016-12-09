// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'ast/selector.dart';
import 'callable.dart';
import 'environment.dart';
import 'exception.dart';
import 'extend/extender.dart';
import 'util/character.dart';
import 'util/number.dart';
import 'utils.dart';
import 'value.dart';

/// A regular expression matching the beginning of a proprietary Microsoft
/// filter declaration.
final _microsoftFilterStart = new RegExp(r'^[a-zA-Z]+\s*=');

/// Feature names supported by Dart sass.
final _features = new Set.from([
  "global-variable-shadowing",
  "extend-selector-pseudoclass",
  "units-level-3",
  "at-error",
  "custom-property"
]);

/// A random number generator.
final _random = new math.Random();

// We use base-36 so we can use the (26-character) alphabet and all digits.
var _uniqueID = _random.nextInt(math.pow(36, 6) as int);

/// Adds all core-library function definitions to [environment].
void defineCoreFunctions(Environment environment) {
  // ## Colors
  // ### RGB

  environment.defineFunction("rgb", r"$red, $green, $blue", (arguments) {
    if (arguments[0].isCalc || arguments[1].isCalc || arguments[2].isCalc) {
      return _functionString('rgb', arguments);
    }

    var red = arguments[0].assertNumber("red");
    var green = arguments[1].assertNumber("green");
    var blue = arguments[2].assertNumber("blue");

    return new SassColor.rgb(
        fuzzyRound(_percentageOrUnitless(red, 255, "red")),
        fuzzyRound(_percentageOrUnitless(green, 255, "green")),
        fuzzyRound(_percentageOrUnitless(blue, 255, "blue")));
  });

  environment.setFunction(new BuiltInCallable.overloaded("rgba", [
    r"$red, $green, $blue, $alpha",
    r"$color, $alpha",
  ], [
    (arguments) {
      if (arguments[0].isCalc ||
          arguments[1].isCalc ||
          arguments[2].isCalc ||
          arguments[3].isCalc) {
        return _functionString('rgba', arguments);
      }

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

      if (arguments[1].isCalc) {
        return new SassString(
            "rgba(${color.red}, ${color.green}, ${color.blue}, "
            "${arguments[1].toCssString()})");
      }

      var alpha = arguments[1].assertNumber("alpha");
      return color.changeAlpha(_percentageOrUnitless(alpha, 1, "alpha"));
    }
  ]));

  environment.defineFunction("red", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").red);
  });

  environment.defineFunction("green", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").green);
  });

  environment.defineFunction("blue", r"$color", (arguments) {
    return new SassNumber(arguments.first.assertColor("color").blue);
  });

  environment.defineFunction("mix", r"$color1, $color2, $weight: 50%",
      (arguments) {
    var color1 = arguments[0].assertColor("color1");
    var color2 = arguments[1].assertColor("color2");
    var weight = arguments[2].assertNumber("weight");
    return _mix(color1, color2, weight);
  });

  // ### HSL

  environment.defineFunction("hsl", r"$hue, $saturation, $lightness",
      (arguments) {
    if (arguments[0].isCalc || arguments[1].isCalc || arguments[2].isCalc) {
      return _functionString("hsl", arguments);
    }

    var hue = arguments[0].assertNumber("hue");
    var saturation = arguments[1].assertNumber("saturation");
    var lightness = arguments[2].assertNumber("lightness");

    return new SassColor.hsl(hue.value, saturation.value, lightness.value);
  });

  environment.defineFunction("hsla", r"$hue, $saturation, $lightness, $alpha",
      (arguments) {
    if (arguments[0].isCalc ||
        arguments[1].isCalc ||
        arguments[2].isCalc ||
        arguments[3].isCalc) {
      return _functionString("hsla", arguments);
    }

    var hue = arguments[0].assertNumber("hue");
    var saturation = arguments[1].assertNumber("saturation");
    var lightness = arguments[2].assertNumber("lightness");
    var alpha = arguments[3].assertNumber("alpha");

    return new SassColor.hsl(hue.value, saturation.value, lightness.value,
        _percentageOrUnitless(alpha, 1, "alpha"));
  });

  environment.defineFunction(
      "hue",
      r"$color",
      (arguments) =>
          new SassNumber(arguments.first.assertColor("color").hue, "deg"));

  environment.defineFunction(
      "saturation",
      r"$color",
      (arguments) =>
          new SassNumber(arguments.first.assertColor("color").saturation, "%"));

  environment.defineFunction(
      "lightness",
      r"$color",
      (arguments) =>
          new SassNumber(arguments.first.assertColor("color").lightness, "%"));

  environment.defineFunction("adjust-hue", r"$color, $degrees", (arguments) {
    var color = arguments[0].assertColor("color");
    var degrees = arguments[1].assertNumber("degrees");
    return color.changeHsl(hue: color.hue + degrees.value);
  });

  environment.defineFunction("lighten", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        lightness: (color.lightness + amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));
  });

  environment.defineFunction("darken", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        lightness: (color.lightness - amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));
  });

  environment.setFunction(new BuiltInCallable.overloaded("saturate", [
    r"$number",
    r"$color, $amount",
  ], [
    (arguments) {
      var number = arguments[0].assertNumber("number");
      return new SassString("saturate(${number.toCssString()})");
    },
    (arguments) {
      var color = arguments[0].assertColor("color");
      var amount = arguments[1].assertNumber("amount");
      return color.changeHsl(
          saturation: (color.saturation + amount.valueInRange(0, 100, "amount"))
              .clamp(0, 100));
    }
  ]));

  environment.defineFunction("desaturate", r"$color, $amount", (arguments) {
    var color = arguments[0].assertColor("color");
    var amount = arguments[1].assertNumber("amount");
    return color.changeHsl(
        saturation: (color.saturation - amount.valueInRange(0, 100, "amount"))
            .clamp(0, 100));
  });

  environment.defineFunction("grayscale", r"$color", (arguments) {
    if (arguments[0] is SassNumber) {
      return _functionString('grayscale', arguments);
    }

    var color = arguments[0].assertColor("color");
    return color.changeHsl(saturation: 0);
  });

  environment.defineFunction("complement", r"$color", (arguments) {
    var color = arguments[0].assertColor("color");
    return color.changeHsl(hue: color.hue + 180);
  });

  environment.defineFunction("invert", r"$color, $weight: 50%", (arguments) {
    if (arguments[0] is SassNumber) {
      // TODO: find some way of ensuring this is stringified using the right
      // options. We may need to resort to zones.
      return _functionString("invert", arguments.take(1));
    }

    var color = arguments[0].assertColor("color");
    var weight = arguments[1].assertNumber("weight");
    var inverse = color.changeRgb(
        red: 255 - color.red, green: 255 - color.green, blue: 255 - color.blue);
    if (weight.value == 50) return inverse;

    return _mix(color, inverse, weight);
  });

  // ### Opacity

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
        return _functionString("alpha", arguments);
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
        return _functionString("alpha", arguments);
      }

      assert(arguments.length != 1);
      throw new SassScriptException(
          "Only 1 argument allowed, but ${arguments.length} were passed.");
    }
  ]));

  environment.defineFunction("opacity", r"$color", (arguments) {
    if (arguments[0] is SassNumber) {
      return _functionString("opacity", arguments);
    }

    var color = arguments[0].assertColor("color");
    return new SassNumber(color.alpha);
  });

  environment.defineFunction("opacify", r"$color, $amount", _opacify);
  environment.defineFunction("fade-in", r"$color, $amount", _opacify);
  environment.defineFunction(
      "transparentize", r"$color, $amount", _transparentize);
  environment.defineFunction("fade-out", r"$color, $amount", _transparentize);

  // ### Miscellaneous

  environment.defineFunction("adjust-color", r"$color, $kwargs...",
      (arguments) {
    var color = arguments[0].assertColor("color");
    var argumentList = arguments[1] as SassArgumentList;
    if (argumentList.contents.isNotEmpty) {
      throw new SassScriptException(
          "Only only positional argument is allowed. All other arguments must "
          "be passed by name.");
    }

    var keywords = normalizedMap(argumentList.keywords);
    getInRange(String name, num min, num max) =>
        keywords.remove(name)?.assertNumber(name)?.valueInRange(min, max, name);

    var red = getInRange("red", -255, 255)?.round();
    var green = getInRange("green", -255, 255)?.round();
    var blue = getInRange("blue", -255, 255)?.round();
    var hue = keywords.remove("hue")?.assertNumber("hue")?.value;
    var saturation = getInRange("saturation", -100, 100);
    var lightness = getInRange("lightness", -100, 100);
    var alpha = getInRange("alpha", -1, 1);

    if (keywords.isNotEmpty) {
      throw new SassScriptException(
          "No ${pluralize('argument', keywords.length)} named "
          "${toSentence(keywords.keys.map((name) => "\$$name"), 'or')}.");
    }

    var hasRgb = red != null || green != null || blue != null;
    var hasHsl = hue != null || saturation != null || lightness != null;
    if (hasRgb) {
      if (hasHsl) {
        throw new SassScriptException(
            "RGB parameters may not be passed along with HSL parameters.");
      }

      return color.changeRgb(
          red: (color.red + (red ?? 0)).clamp(0, 255) as int,
          green: (color.green + (green ?? 0)).clamp(0, 255) as int,
          blue: (color.blue + (blue ?? 0)).clamp(0, 255) as int,
          alpha: (color.alpha + (alpha ?? 0)).clamp(0, 1));
    } else if (hasHsl) {
      return color.changeHsl(
          hue: color.hue + (hue ?? 0),
          saturation: (color.saturation + (saturation ?? 0)).clamp(0, 100),
          lightness: (color.lightness + (lightness ?? 0)).clamp(0, 100),
          alpha: color.alpha + (alpha ?? 0));
    } else {
      return color.changeAlpha((color.alpha + (alpha ?? 0)).clamp(0, 1));
    }
  });

  environment.defineFunction("scale-color", r"$color, $kwargs...", (arguments) {
    var color = arguments[0].assertColor("color");
    var argumentList = arguments[1] as SassArgumentList;
    if (argumentList.contents.isNotEmpty) {
      throw new SassScriptException(
          "Only only positional argument is allowed. All other arguments must "
          "be passed by name.");
    }

    var keywords = normalizedMap(argumentList.keywords);
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
      throw new SassScriptException(
          "No ${pluralize('argument', keywords.length)} named "
          "${toSentence(keywords.keys.map((name) => "\$$name"), 'or')}.");
    }

    var hasRgb = red != null || green != null || blue != null;
    var hasHsl = saturation != null || lightness != null;
    if (hasRgb) {
      if (hasHsl) {
        throw new SassScriptException(
            "RGB parameters may not be passed along with HSL parameters.");
      }

      return color.changeRgb(
          red: scaleValue(color.red, red, 255).round(),
          green: scaleValue(color.green, green, 255).round(),
          blue: scaleValue(color.blue, blue, 255).round(),
          alpha: scaleValue(color.alpha, alpha, 1));
    } else if (hasHsl) {
      return color.changeHsl(
          saturation: scaleValue(color.saturation, saturation, 100),
          lightness: scaleValue(color.lightness, lightness, 100),
          alpha: scaleValue(color.alpha, alpha, 1));
    } else {
      return color.changeAlpha(scaleValue(color.alpha, alpha, 1));
    }
  });

  environment.defineFunction("change-color", r"$color, $kwargs...",
      (arguments) {
    var color = arguments[0].assertColor("color");
    var argumentList = arguments[1] as SassArgumentList;
    if (argumentList.contents.isNotEmpty) {
      throw new SassScriptException(
          "Only only positional argument is allowed. All other arguments must "
          "be passed by name.");
    }

    var keywords = normalizedMap(argumentList.keywords);
    getInRange(String name, num min, num max) =>
        keywords.remove(name)?.assertNumber(name)?.valueInRange(min, max, name);

    var red = getInRange("red", 0, 255)?.round();
    var green = getInRange("green", 0, 255)?.round();
    var blue = getInRange("blue", 0, 255)?.round();
    var hue = keywords.remove("hue")?.assertNumber("hue")?.value;
    var saturation = getInRange("saturation", 0, 100);
    var lightness = getInRange("lightness", 0, 100);
    var alpha = getInRange("alpha", 0, 1);

    if (keywords.isNotEmpty) {
      throw new SassScriptException(
          "No ${pluralize('argument', keywords.length)} named "
          "${toSentence(keywords.keys.map((name) => "\$$name"), 'or')}.");
    }

    var hasRgb = red != null || green != null || blue != null;
    var hasHsl = saturation != null || lightness != null;
    if (hasRgb) {
      if (hasHsl) {
        throw new SassScriptException(
            "RGB parameters may not be passed along with HSL parameters.");
      }

      return color.changeRgb(red: red, green: green, blue: blue, alpha: alpha);
    } else if (hasHsl) {
      return color.changeHsl(
          hue: hue, saturation: saturation, lightness: lightness, alpha: alpha);
    } else {
      return color.changeAlpha(alpha);
    }
  });

  environment.defineFunction("ie-hex-str", r"$color", (arguments) {
    var color = arguments[0].assertColor("color");
    hexString(int component) =>
        component.toRadixString(16).padLeft(2, '0').toUpperCase();
    return new SassString(
        "#${hexString(fuzzyRound(color.alpha * 255))}${hexString(color.red)}"
        "${hexString(color.green)}${hexString(color.blue)}");
  });

  // ## Strings

  environment.defineFunction("unquote", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    if (!string.hasQuotes) return string;
    return new SassString(string.text);
  });

  environment.defineFunction("quote", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    if (string.hasQuotes) return string;
    return new SassString(string.text, quotes: true);
  });

  environment.defineFunction("str-length", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    return new SassNumber(string.text.runes.length);
  });

  environment.defineFunction("str-insert", r"$string, $insert, $index",
      (arguments) {
    var string = arguments[0].assertString("string");
    var insert = arguments[1].assertString("insert");
    var index = arguments[2].assertNumber("index");
    index.assertNoUnits("index");

    var codeUnitIndex = codepointIndexToCodeUnitIndex(string.text,
        _codepointForIndex(index.assertInt("index"), string.text.runes.length));
    return new SassString(
        string.text.replaceRange(codeUnitIndex, codeUnitIndex, insert.text),
        quotes: string.hasQuotes);
  });

  environment.defineFunction("str-index", r"$string, $substring", (arguments) {
    var string = arguments[0].assertString("string");
    var substring = arguments[1].assertString("substring");

    var codeUnitIndex = string.text.indexOf(substring.text);
    if (codeUnitIndex == -1) return sassNull;
    var codepointIndex =
        codeUnitIndexToCodepointIndex(string.text, codeUnitIndex);
    return new SassNumber(codepointIndex + 1);
  });

  environment.defineFunction("str-slice", r"$string, $start-at, $end-at: -1",
      (arguments) {
    var string = arguments[0].assertString("string");
    var start = arguments[1].assertNumber("start-at");
    var end = arguments[2].assertNumber("end-at");
    start.assertNoUnits("start");
    end.assertNoUnits("end");

    var lengthInCodepoints = string.text.runes.length;
    var startCodepoint =
        _codepointForIndex(start.assertInt(), lengthInCodepoints);
    var endCodepoint = _codepointForIndex(end.assertInt(), lengthInCodepoints);
    return new SassString(
        string.text.substring(
            codepointIndexToCodeUnitIndex(string.text, startCodepoint),
            codepointIndexToCodeUnitIndex(string.text, endCodepoint) + 1),
        quotes: string.hasQuotes);
  });

  environment.defineFunction("to-upper-case", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    var buffer = new StringBuffer();
    for (var i = 0; i < string.text.length; i++) {
      buffer.writeCharCode(toUpperCase(string.text.codeUnitAt(i)));
    }
    return new SassString(buffer.toString(), quotes: string.hasQuotes);
  });

  environment.defineFunction("to-lower-case", r"$string", (arguments) {
    var string = arguments[0].assertString("string");
    var buffer = new StringBuffer();
    for (var i = 0; i < string.text.length; i++) {
      buffer.writeCharCode(toLowerCase(string.text.codeUnitAt(i)));
    }
    return new SassString(buffer.toString(), quotes: string.hasQuotes);
  });

  // ## Numbers

  environment.defineFunction("percentage", r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    number.assertNoUnits("number");
    return new SassNumber(number.value * 100, '%');
  });

  environment.setFunction(_numberFunction("round", fuzzyRound));
  environment.setFunction(_numberFunction("ceil", (value) => value.ceil()));
  environment.setFunction(_numberFunction("floor", (value) => value.floor()));
  environment.setFunction(_numberFunction("abs", (value) => value.abs()));

  environment.defineFunction("max", r"$numbers...", (arguments) {
    SassNumber max;
    for (var value in arguments[0].asList) {
      var number = value.assertNumber();
      if (max == null || max.lessThan(number).isTruthy) max = number;
    }
    if (max != null) return max;
    throw new SassScriptException("At least one argument must be passed.");
  });

  environment.defineFunction("min", r"$numbers...", (arguments) {
    SassNumber min;
    for (var value in arguments[0].asList) {
      var number = value.assertNumber();
      if (min == null || min.greaterThan(number).isTruthy) min = number;
    }
    if (min != null) return min;
    throw new SassScriptException("At least one argument must be passed.");
  });

  environment.defineFunction("random", r"$limit: null", (arguments) {
    if (arguments[0] == sassNull) return new SassNumber(_random.nextDouble());
    var limit = arguments[0].assertNumber("limit").assertInt("limit");
    if (limit < 1) {
      throw new SassScriptException(
          "\$limit: Must be greater than 0, was $limit.");
    }
    return new SassNumber(_random.nextInt(limit) + 1);
  });

  // ## Lists

  environment.defineFunction("length", r"$list",
      (arguments) => new SassNumber(arguments[0].asList.length));

  environment.defineFunction("nth", r"$list, $n", (arguments) {
    var list = arguments[0].asList;
    var index = arguments[1].assertNumber("n");
    return list[index.assertIndexFor(list, "n")];
  });

  environment.defineFunction("set-nth", r"$list, $n, $value", (arguments) {
    var list = arguments[0].asList;
    var index = arguments[1].assertNumber("n");
    var value = arguments[2];
    var newList = list.toList();
    newList[index.assertIndexFor(list, "n")] = value;
    return arguments[0].changeListContents(newList);
  });

  environment.defineFunction(
      "join", r"$list1, $list2, $separator: auto, $bracketed: auto",
      (arguments) {
    var list1 = arguments[0];
    var list2 = arguments[1];
    var separatorParam = arguments[2].assertString("separator");
    var bracketedParam = arguments[3];

    ListSeparator separator;
    if (separatorParam.text == "auto") {
      if (list1.separator != ListSeparator.undecided) {
        separator = list1.separator;
      } else if (list2.separator != ListSeparator.undecided) {
        separator = list2.separator;
      } else {
        separator = ListSeparator.space;
      }
    } else if (separatorParam.text == "space") {
      separator = ListSeparator.space;
    } else if (separatorParam.text == "comma") {
      separator = ListSeparator.comma;
    } else {
      throw new SassScriptException(
          '\$$separator: Must be "space", "comma", or "auto".');
    }

    var bracketed =
        bracketedParam is SassString && bracketedParam.text == 'auto'
            ? list1.hasBrackets
            : bracketedParam.isTruthy;

    var newList = list1.asList.toList()..addAll(list2.asList);
    return new SassList(newList, separator, brackets: bracketed);
  });

  environment.defineFunction("append", r"$list, $val, $separator: auto",
      (arguments) {
    var list = arguments[0];
    var value = arguments[1];
    var separatorParam = arguments[2].assertString("separator");

    ListSeparator separator;
    if (separatorParam.text == "auto") {
      separator = list.separator == ListSeparator.undecided
          ? ListSeparator.space
          : list.separator;
    } else if (separatorParam.text == "space") {
      separator = ListSeparator.space;
    } else if (separatorParam.text == "comma") {
      separator = ListSeparator.comma;
    } else {
      throw new SassScriptException(
          '\$$separator: Must be "space", "comma", or "auto".');
    }

    var newList = list.asList.toList()..add(value);
    return list.changeListContents(newList, separator: separator);
  });

  environment.defineFunction("zip", r"$lists...", (arguments) {
    var lists = (arguments[0] as SassArgumentList)
        .contents
        .map((list) => list.asList)
        .toList();
    var i = 0;
    var results = <SassList>[];
    while (lists.every((list) => i != list.length)) {
      results
          .add(new SassList(lists.map((list) => list[i]), ListSeparator.space));
      i++;
    }
    return new SassList(results, ListSeparator.comma);
  });

  environment.defineFunction("index", r"$list, $value", (arguments) {
    var list = arguments[0].asList;
    var value = arguments[1];

    var index = list.indexOf(value);
    return index == -1 ? sassNull : new SassNumber(index + 1);
  });

  environment.defineFunction(
      "list-separator",
      r"$list",
      (arguments) => arguments[0].separator == ListSeparator.comma
          ? new SassString("comma")
          : new SassString("space"));

  environment.defineFunction("is-bracketed", r"$list",
      (arguments) => new SassBoolean(arguments[0].hasBrackets));

  // ## Maps

  environment.defineFunction("map-get", r"$map, $key", (arguments) {
    var map = arguments[0].assertMap("map");
    var key = arguments[1];
    return map.contents[key] ?? sassNull;
  });

  environment.defineFunction("map-merge", r"$map1, $map2", (arguments) {
    var map1 = arguments[0].assertMap("map1");
    var map2 = arguments[1].assertMap("map2");
    return new SassMap(new Map.from(map1.contents)..addAll(map2.contents));
  });

  environment.defineFunction("map-remove", r"$map, $keys...", (arguments) {
    var map = arguments[0].assertMap("map");
    var keys = arguments[1] as SassArgumentList;
    var mutableMap = new Map<Value, Value>.from(map.contents);
    for (var key in keys.contents) {
      mutableMap.remove(key);
    }
    return new SassMap(mutableMap);
  });

  environment.defineFunction(
      "map-keys",
      r"$map",
      (arguments) => new SassList(
          arguments[0].assertMap("map").contents.keys, ListSeparator.comma));

  environment.defineFunction(
      "map-values",
      r"$map",
      (arguments) => new SassList(
          arguments[0].assertMap("map").contents.values, ListSeparator.comma));

  environment.defineFunction("map-has-key", r"$map, $key", (arguments) {
    var map = arguments[0].assertMap("map");
    var key = arguments[1];
    return new SassBoolean(map.contents.containsKey(key));
  });

  environment.defineFunction("keywords", r"$args", (arguments) {
    var argumentList = arguments[0];
    if (argumentList is SassArgumentList) {
      return new SassMap(mapMap(argumentList.keywords,
          key: (String key, Value _) => new SassString(key)));
    } else {
      throw new SassScriptException(
          "\$args: $argumentList is not an argument list.");
    }
  });

  // ## Selectors

  environment.defineFunction("selector-nest", r"$selectors...", (arguments) {
    var selectors = (arguments[0] as SassArgumentList).contents;
    if (selectors.isEmpty) {
      throw new SassScriptException(
          "\$selectors: At least one selector must be passed.");
    }

    return selectors
        .map((selector) => selector.assertSelector(allowParent: true))
        .reduce((parent, child) => child.resolveParentSelectors(parent))
        .asSassList;
  });

  environment.defineFunction("selector-append", r"$selectors...", (arguments) {
    var selectors = (arguments[0] as SassArgumentList).contents;
    if (selectors.isEmpty) {
      throw new SassScriptException(
          "\$selectors: At least one selector must be passed.");
    }

    return selectors
        .map((selector) => selector.assertSelector())
        .reduce((parent, child) {
      return new SelectorList(child.components.map((complex) {
        var compound = complex.components.first;
        if (compound is CompoundSelector) {
          var newCompound = _prependParent(compound);
          if (newCompound == null) {
            throw new SassScriptException("Can't append $complex to $parent.");
          }

          return new ComplexSelector(<ComplexSelectorComponent>[newCompound]
            ..addAll(complex.components.skip(1)));
        } else {
          throw new SassScriptException("Can't append $complex to $parent.");
        }
      })).resolveParentSelectors(parent);
    }).asSassList;
  });

  environment.defineFunction(
      "selector-extend", r"$selector, $extendee, $extender", (arguments) {
    var selector = arguments[0].assertSelector(name: "selector");
    var target = arguments[1].assertSimpleSelector(name: "extendee");
    var source = arguments[2].assertSelector(name: "extender");

    return Extender.extend(selector, source, target).asSassList;
  });

  environment.defineFunction(
      "selector-replace", r"$selector, $original, $replacement", (arguments) {
    var selector = arguments[0].assertSelector(name: "selector");
    var target = arguments[1].assertSimpleSelector(name: "original");
    var source = arguments[2].assertSelector(name: "replacement");

    return Extender.replace(selector, source, target).asSassList;
  });

  environment.defineFunction("selector-unify", r"$selector1, $selector2",
      (arguments) {
    var selector1 = arguments[0].assertSelector(name: "selector1");
    var selector2 = arguments[1].assertSelector(name: "selector2");

    var result = selector1.unify(selector2);
    return result == null ? sassNull : result.asSassList;
  });

  environment.defineFunction("is-superselector", r"$super, $sub", (arguments) {
    var selector1 = arguments[0].assertSelector(name: "super");
    var selector2 = arguments[1].assertSelector(name: "sub");

    return new SassBoolean(selector1.isSuperselector(selector2));
  });

  environment.defineFunction("simple-selectors", r"$selector", (arguments) {
    var selector = arguments[0].assertCompoundSelector(name: "selector");

    return new SassList(
        selector.components.map((simple) => new SassString(simple.toString())),
        ListSeparator.comma);
  });

  environment.defineFunction("selector-parse", r"$selector",
      (arguments) => arguments[0].assertSelector(name: "selector").asSassList);

  // ## Introspection

  environment.defineFunction("feature-exists", r"$feature", (arguments) {
    var feature = arguments[0].assertString("feature");
    return new SassBoolean(_features.contains(feature.text));
  });

  environment.defineFunction("variable-exists", r"$name", (arguments) {
    var variable = arguments[0].assertString("name");
    return new SassBoolean(environment.variableExists(variable.text));
  });

  environment.defineFunction("global-variable-exists", r"$name", (arguments) {
    var variable = arguments[0].assertString("name");
    return new SassBoolean(environment.globalVariableExists(variable.text));
  });

  environment.defineFunction("function-exists", r"$name", (arguments) {
    var variable = arguments[0].assertString("name");
    return new SassBoolean(environment.functionExists(variable.text));
  });

  environment.defineFunction("mixin-exists", r"$name", (arguments) {
    var variable = arguments[0].assertString("name");
    return new SassBoolean(environment.mixinExists(variable.text));
  });

  environment.defineFunction("inspect", r"$value",
      (arguments) => new SassString(arguments.first.toString()));

  environment.defineFunction("type-of", r"$value", (arguments) {
    var value = arguments[0];
    if (value is SassArgumentList) return new SassString("arglist");
    if (value is SassBoolean) return new SassString("bool");
    if (value is SassColor) return new SassString("color");
    if (value is SassList) return new SassString("list");
    if (value is SassMap) return new SassString("map");
    if (value is SassNull) return new SassString("null");
    if (value is SassNumber) return new SassString("number");
    assert(value is SassString);
    return new SassString("string");
  });

  environment.defineFunction("unit", r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    return new SassString(number.unitString, quotes: true);
  });

  environment.defineFunction("unitless", r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    return new SassBoolean(!number.hasUnits);
  });

  environment.defineFunction("comparable", r"$number1, $number2", (arguments) {
    var number1 = arguments[0].assertNumber("number1");
    var number2 = arguments[1].assertNumber("number2");
    return new SassBoolean(number1.isComparableTo(number2));
  });

  environment.defineFunction("get-function", r"$name, $css: false",
      (arguments) {
    var name = arguments[0].assertString("name");
    var css = arguments[1].isTruthy;

    var callable = css
        ? new PlainCssCallable(name.text)
        : environment.getFunction(name.text);
    if (callable != null) return new SassFunction(callable);

    throw new SassScriptException("Function not found: $name");
  });

  // call() is defined in _PerformVisitor to provide it access to private APIs.

  // ## Miscellaneous

  // This is only invoked using `call()`. Hand-authored `if()`s are parsed as
  // [IfExpression]s.
  environment.defineFunction("if", r"$condition, $if-true, $if-false",
      (arguments) => arguments[0].isTruthy ? arguments[1] : arguments[2]);

  environment.defineFunction("unique-id", "", (arguments) {
    // Make it difficult to guess the next ID by randomizing the increase.
    _uniqueID += _random.nextInt(36) + 1;
    if (_uniqueID > math.pow(36, 6)) _uniqueID %= math.pow(36, 6) as int;
    // The leading "u" ensures that the result is a valid identifier.
    return new SassString("u${_uniqueID.toRadixString(36).padLeft(6, '0')}");
  });
}

/// Returns a string representation of [name] called with [arguments], as though
/// it were a plain CSS function.
SassString _functionString(String name, Iterable<Value> arguments) =>
    new SassString("$name(" +
        arguments.map((argument) => argument.toCssString()).join(', ') +
        ")");

/// Asserts that [number] is a percentage or has no units, and normalizes the
/// value.
///
/// If [number] has no units, its value is clamped to be greater than `0` or
/// less than [max] and returned. If [number] is a percentage, it's scaled to be
/// within `0` and [max]. Otherwise, this throws a [SassScriptException].
///
/// [name] is used to identify the argument in the error message.
num _percentageOrUnitless(SassNumber number, num max, String name) {
  num value;
  if (!number.hasUnits) {
    value = number.value;
  } else if (number.hasUnit("%")) {
    value = max * number.value / 100;
  } else {
    throw new SassScriptException(
        '\$$name: Expected $number to have no units or "%".');
  }

  return value.clamp(0, max);
}

/// Returns [color1] and [color2], mixed together and weighted by [weight].
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

/// The definition of the `opacify()` and `fade-in()` functions.
SassColor _opacify(List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");

  return color.changeAlpha(
      (color.alpha + amount.valueInRange(0, 1, "amount")).clamp(0, 1));
}

/// The definition of the `transparentize()` and `fade-out()` functions.
SassColor _transparentize(List<Value> arguments) {
  var color = arguments[0].assertColor("color");
  var amount = arguments[1].assertNumber("amount");

  return color.changeAlpha(
      (color.alpha - amount.valueInRange(0, 1, "amount")).clamp(0, 1));
}

/// Converts a Sass string index into a codepoint index into a string whose
/// [String.runes] has length [lengthInCodepoints].
///
/// A Sass string index is one-based, and uses negative numbers to count
/// backwards from the end of the string. A codepoint index is an index into
/// [String.runes].
int _codepointForIndex(int index, int lengthInCodepoints) {
  if (index == 0) return 0;
  if (index > 0) return math.min(index - 1, lengthInCodepoints);
  return math.max(lengthInCodepoints + index, 0);
}

/// Returns a [BuiltInCallable] named [name] that transforms a number's value
/// using [transform] and preserves its units.
BuiltInCallable _numberFunction(String name, num transform(num value)) {
  return new BuiltInCallable(name, r"$number", (arguments) {
    var number = arguments[0].assertNumber("number");
    return new SassNumber.withUnits(transform(number.value),
        numeratorUnits: number.numeratorUnits,
        denominatorUnits: number.denominatorUnits);
  });
}

/// Adds a [ParentSelector] to the beginning of [compound], or returns `null` if
/// that wouldn't produce a valid selector.
CompoundSelector _prependParent(CompoundSelector compound) {
  var first = compound.components.first;
  if (first is UniversalSelector) return null;
  if (first is TypeSelector) {
    if (first.name.namespace != null) return null;
    return new CompoundSelector(<SimpleSelector>[
      new ParentSelector(suffix: first.name.name)
    ]..addAll(compound.components.skip(1)));
  } else {
    return new CompoundSelector(
        <SimpleSelector>[new ParentSelector()]..addAll(compound.components));
  }
}
