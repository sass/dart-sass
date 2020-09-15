// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  group("a function value", () {
    SassFunction value;
    setUp(() => value = parseValue("get-function('red')") as SassFunction);

    test("has a callable with the given name", () {
      expect(value.callable.name, equals("red"));
    });

    test("is a function", () {
      expect(value.assertFunction(), equals(value));
    });

    test("equals the same function", () {
      expect(value, equalsWithHash(parseValue("get-function('red')")));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  test("can return a new function", () {
    var css = compileString("a {b: call(foo(), 12)}", functions: [
      Callable("foo", "", (_) {
        return SassFunction(Callable("bar", r"$arg",
            (arguments) => SassNumber(arguments[0].assertNumber().value + 1)));
      })
    ]);

    expect(css, equalsIgnoringWhitespace("a { b: 13; }"));
  });
}
