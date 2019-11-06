// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  group("true", () {
    Value value;
    setUp(() => value = parseValue("true"));

    test("is truthy", () {
      expect(value.isTruthy, isTrue);
    });

    test("is sassTrue", () {
      expect(value, equalsWithHash(sassTrue));
    });

    test("is a boolean", () {
      expect(value.assertBoolean(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("false", () {
    Value value;
    setUp(() => value = parseValue("false"));

    test("is falsey", () {
      expect(value.isTruthy, isFalse);
    });

    test("is sassFalse", () {
      expect(value, equalsWithHash(sassFalse));
    });

    test("is a boolean", () {
      expect(value.assertBoolean(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("new SassBoolean()", () {
    test("returns sassTrue", () {
      expect(SassBoolean(true), equals(sassTrue));
    });

    test("returns sassFalse", () {
      expect(SassBoolean(false), equals(sassFalse));
    });
  });
}
