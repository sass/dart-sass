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
        _percentageOrUnitless(red, 255, "red"),
        _percentageOrUnitless(green, 255, "green"),
        _percentageOrUnitless(blue, 255, "blue"));
  }));

  environment.setFunction(new BuiltInCallable(
      "inspect",
      new ArgumentDeclaration([new Argument("value")]),
      (arguments) => new SassString(arguments.single.toString())));
}

int _percentageOrUnitless(SassNumber number, int max, String name) {
  num value;
  if (!number.hasUnits) {
    value = number.value;
  } else if (number.hasUnit("%")) {
    value = max * number.value / 100;
  } else {
    throw new InternalException(
        '\$$name: Expected $number to have no units or "%".');
  }

  return value.clamp(0, max).round();
}
