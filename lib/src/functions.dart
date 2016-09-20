// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'callable.dart';
import 'environment.dart';
import 'exception.dart';
import 'value.dart';

void defineCoreFunctions(Environment environment) {
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
      "inspect",
      new ArgumentDeclaration([new Argument("value")]),
      (arguments) => new SassString(arguments.single.toString())));
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
