// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'callable.dart';
import 'environment.dart';
import 'exception.dart';
import 'value.dart';

void defineCoreFunctions(Environment environment) {
  // ## RGB Functions

  environment.setFunction(new BuiltInCallable(
      "rgb",
      new ArgumentDeclaration(
          [new Argument("red"), new Argument("green"), new Argument("blue")]),
      (arguments) {
    var red = arguments[0].assertNumber("red");
    var green = arguments[1].assertNumber("green");
    var blue = arguments[2].assertNumber("blue");

    return new SassColor.rgb(
        _percentageOrUnitless(red, 255, "red").round(),
        _percentageOrUnitless(green, 255, "green").round(),
        _percentageOrUnitless(blue, 255, "blue").round());
  }));

  environment.setFunction(new BuiltInCallable.overloaded("rgba", [
    new ArgumentDeclaration([
      new Argument("red"),
      new Argument("green"),
      new Argument("blue"),
      new Argument("alpha")
    ]),
    new ArgumentDeclaration([new Argument("color"), new Argument("alpha")]),
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

      return color.change(alpha: _percentageOrUnitless(alpha, 1, "alpha"));
    }
  ]));

  environment.setFunction(new BuiltInCallable(
      "mix",
      new ArgumentDeclaration([
        new Argument("color1"),
        new Argument("color2"),
        new Argument("weight",
            // TODO(nweiz): Find a better way to declare arguments so we don't
            // have to pass `null` explicitly.
            defaultValue: new NumberExpression(50, null, unit: "%"))
      ]), (arguments) {
    var color1 = arguments[0].assertColor("color1");
    var color2 = arguments[1].assertColor("color2");
    var weight = arguments[2].assertNumber("weight");

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
  }));

  // ## Introspection Functions

  environment.setFunction(new BuiltInCallable(
      "inspect",
      new ArgumentDeclaration([new Argument("value")]),
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
