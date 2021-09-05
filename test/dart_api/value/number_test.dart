// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'dart:math' as math;

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  group("a unitless integer", () {
    late SassNumber value;
    setUp(() => value = parseValue("123") as SassNumber);

    test("has the correct value", () {
      expect(value.value, equals(123));
      expect(value.value, const TypeMatcher<int>());
    });

    test("has no units", () {
      expect(value.numeratorUnits, isEmpty);
      expect(value.denominatorUnits, isEmpty);
      expect(value.hasUnits, isFalse);
      expect(value.hasUnit("px"), isFalse);
      expect(() => value.assertUnit("px"), throwsSassScriptException);
      value.assertNoUnits(); // Should not throw.
    });

    test("is an int", () {
      expect(value.isInt, isTrue);
      expect(value.asInt, equals(123));
      expect(value.assertInt(), equals(123));
    });

    test("can be coerced to unitless", () {
      expect(value.coerce([], []), equals(SassNumber.withUnits(123)));
    });

    test("can be coerced to any units", () {
      expect(
          value.coerce(["abc"], ["def"]),
          equals(SassNumber.withUnits(123,
              numeratorUnits: ["abc"], denominatorUnits: ["def"])));
    });

    test("can be converted to unitless", () {
      expect(value.convertToMatch(SassNumber(456)),
          equals(SassNumber.withUnits(123)));
    });

    test("can't be converted to a unit", () {
      expect(() => value.convertToMatch(SassNumber(456, "px")),
          throwsSassScriptException);
    });

    test("can coerce its value to unitless", () {
      expect(value.coerceValue([], []), equals(123));
    });

    test("can coerce its value to any units", () {
      expect(value.coerceValue(["abc"], ["def"]), equals(123));
    });

    test("can convert its value to unitless", () {
      expect(value.convertValueToMatch(SassNumber(456)), equals(123));
    });

    test("can't convert its value to any units", () {
      expect(() => value.convertValueToMatch(SassNumber(456, "px")),
          throwsSassScriptException);
    });

    test("is compatible with any unit", () {
      expect(value.compatibleWithUnit("px"), isTrue);
    });

    group("valueInRange()", () {
      test("returns its value within a given range", () {
        expect(value.valueInRange(0, 123), equals(123));
        expect(value.valueInRange(123, 123), equals(123));
        expect(value.valueInRange(123, 1000), equals(123));
      });

      test("rejects a value outside the range", () {
        expect(() => value.valueInRange(0, 122), throwsSassScriptException);
        expect(() => value.valueInRange(124, 1000), throwsSassScriptException);
      });
    });

    test("equals the same number", () {
      expect(value, equalsWithHash(SassNumber(123)));
    });

    test("equals the same number within precision tolerance", () {
      expect(
          value,
          equalsWithHash(
              SassNumber(123 + math.pow(10, -SassNumber.precision - 2))));
      expect(
          value,
          equalsWithHash(
              SassNumber(123 - math.pow(10, -SassNumber.precision - 2))));
    });

    test("doesn't equal a different number", () {
      expect(value, isNot(equals(SassNumber(124))));
      expect(value, isNot(equals(SassNumber(122))));
      expect(
          value,
          isNot(equals(
              SassNumber(123 + math.pow(10, -SassNumber.precision - 1)))));
      expect(
          value,
          isNot(equals(
              SassNumber(123 - math.pow(10, -SassNumber.precision - 1)))));
    });

    test("doesn't equal a number with units", () {
      expect(value, isNot(equals(SassNumber(123, "px"))));
    });

    test("is a number", () {
      expect(value.assertNumber(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.tryMap(), isNull);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("a unitless double", () {
    late SassNumber value;
    setUp(() => value = parseValue("123.456") as SassNumber);

    test("has the correct value", () {
      expect(value.value, equals(123.456));
    });

    test("is not an int", () {
      expect(value.isInt, isFalse);
      expect(value.asInt, isNull);
      expect(value.assertInt, throwsSassScriptException);
    });
  });

  group("a unitless fuzzy integer", () {
    late SassNumber value;
    setUp(() => value = parseValue("123.000000000001") as SassNumber);

    test("has the correct value", () {
      expect(value.value, equals(123.000000000001));
    });

    test("is an int", () {
      expect(value.isInt, isTrue);
      expect(value.asInt, equals(123));
      expect(value.assertInt(), equals(123));
    });

    test("equals the same number", () {
      expect(
          value,
          equalsWithHash(
              SassNumber(123 + math.pow(10, -SassNumber.precision - 2))));
    });

    test("equals the same number within precision tolerance", () {
      expect(value, equalsWithHash(SassNumber(123)));
      expect(
          value,
          equalsWithHash(
              SassNumber(123 - math.pow(10, -SassNumber.precision - 2))));
    });

    group("valueInRange()", () {
      test("clamps within the given range", () {
        expect(value.valueInRange(0, 123), equals(123));
        expect(value.valueInRange(123, 123), equals(123));
        expect(value.valueInRange(123, 1000), equals(123));
      });

      test("rejects a value outside the range", () {
        expect(() => value.valueInRange(0, 122), throwsSassScriptException);
        expect(() => value.valueInRange(124, 1000), throwsSassScriptException);
      });
    });
  });

  group("an integer with a single numerator unit", () {
    late SassNumber value;
    setUp(() => value = parseValue("123px") as SassNumber);

    test("has that unit", () {
      expect(value.numeratorUnits, equals(["px"]));
      expect(value.hasUnits, isTrue);
      expect(value.hasUnit("px"), isTrue);
      value.assertUnit("px"); // Should not throw.
      expect(value.assertNoUnits, throwsSassScriptException);
    });

    test("has no other units", () {
      expect(value.denominatorUnits, isEmpty);
      expect(value.hasUnit("in"), isFalse);
      expect(() => value.assertUnit("in"), throwsSassScriptException);
    });

    test("can be coerced to unitless", () {
      expect(value.coerce([], []), equals(SassNumber(123)));
    });

    test("can be coerced to compatible units", () {
      expect(value.coerce(["px"], []), equals(value));
      expect(value.coerce(["in"], []), equals(SassNumber(1.28125, "in")));
    });

    test("can't be coerced to incompatible units", () {
      expect(() => value.coerce(["abc"], []), throwsSassScriptException);
    });

    test("can't be converted to unitless", () {
      expect(() => value.convertToMatch(SassNumber(456)),
          throwsSassScriptException);
    });

    test("can be converted to compatible units", () {
      expect(value.convertToMatch(SassNumber(456, "px")), equals(value));
      expect(value.convertToMatch(SassNumber(456, "in")),
          equals(SassNumber(1.28125, "in")));
    });

    test("can't be converted to incompatible units", () {
      expect(() => value.convertToMatch(SassNumber(456, "abc")),
          throwsSassScriptException);
    });

    test("can coerce its value to unitless", () {
      expect(value.coerceValue([], []), equals(123));
    });

    test("can coerce its value to compatible units", () {
      expect(value.coerceValue(["px"], []), equals(123));
      expect(value.coerceValue(["in"], []), equals(1.28125));
    });

    test("can't coerce its value to incompatible units", () {
      expect(() => value.coerceValue(["abc"], []), throwsSassScriptException);
    });

    test("can't convert its value to unitless", () {
      expect(() => value.convertValueToMatch(SassNumber(456)),
          throwsSassScriptException);
    });

    test("can convert its value to compatible units", () {
      expect(value.convertValueToMatch(SassNumber(456, "px")), equals(123));
      expect(value.convertValueToMatch(SassNumber(456, "in")), equals(1.28125));
    });

    test("can't convert its value to incompatible units", () {
      expect(() => value.convertValueToMatch(SassNumber(456, "abc")),
          throwsSassScriptException);
    });

    test("is compatible with the same unit", () {
      expect(value.compatibleWithUnit("px"), isTrue);
    });

    test("is compatible with a compatible unit", () {
      expect(value.compatibleWithUnit("in"), isTrue);
    });

    test("is incompatible with an incompatible unit", () {
      expect(value.compatibleWithUnit("abc"), isFalse);
    });

    test("equals the same number", () {
      expect(value, equalsWithHash(SassNumber(123, "px")));
    });

    test("equals an equivalent number", () {
      expect(value.hashCode, equals(SassNumber(1.28125, "in").hashCode));
      expect(value, equalsWithHash(SassNumber(1.28125, "in")));
    });

    test("doesn't equal a unitless number", () {
      expect(value, isNot(equals(SassNumber(123))));
    });

    test("doesn't equal a number with different units", () {
      expect(value, isNot(equals(SassNumber(123, "abc"))));
      expect(
          value,
          isNot(
              equals(SassNumber.withUnits(123, numeratorUnits: ["px", "px"]))));
      expect(
          value,
          isNot(equals(SassNumber.withUnits(123,
              numeratorUnits: ["px"], denominatorUnits: ["abc"]))));
      expect(value,
          isNot(equals(SassNumber.withUnits(123, denominatorUnits: ["px"]))));
    });
  });

  group("a number with numerator and denominator units", () {
    late SassNumber value;
    setUp(() => value = parseValue("123px / 5ms") as SassNumber);

    test("has those units", () {
      expect(value.numeratorUnits, equals(["px"]));
      expect(value.denominatorUnits, equals(["ms"]));
      expect(value.hasUnits, isTrue);
      expect(value.assertNoUnits, throwsSassScriptException);
    });

    test("reports false for hasUnit()", () {
      // [hasUnit] and [assertUnit] only allow a single numerator unit.
      expect(value.hasUnit("px"), isFalse);
      expect(() => value.assertUnit("px"), throwsSassScriptException);
    });

    test("can be coerced to unitless", () {
      expect(value.coerce([], []), equals(SassNumber(24.6)));
    });

    test("can be coerced to compatible units", () {
      expect(value.coerce(["px"], ["ms"]), equals(value));
      expect(
          value.coerce(["in"], ["s"]),
          equals(SassNumber.withUnits(256.25,
              numeratorUnits: ["in"], denominatorUnits: ["s"])));
    });

    test("can coerce to match another number", () {
      expect(
          value.coerceToMatch(SassNumber.withUnits(456,
              numeratorUnits: ["in"], denominatorUnits: ["s"])),
          equals(SassNumber.withUnits(256.25,
              numeratorUnits: ["in"], denominatorUnits: ["s"])));
    });

    test("can't be coerced to incompatible units", () {
      expect(() => value.coerce(["abc"], []), throwsSassScriptException);
    });

    test("can't be converted to unitless", () {
      expect(() => value.convertToMatch(SassNumber(456)),
          throwsSassScriptException);
    });

    test("can be converted to compatible units", () {
      expect(
          value.convertToMatch(SassNumber.withUnits(456,
              numeratorUnits: ["px"], denominatorUnits: ["ms"])),
          equals(value));
      expect(
          value.convertToMatch(SassNumber.withUnits(456,
              numeratorUnits: ["in"], denominatorUnits: ["s"])),
          equals(SassNumber.withUnits(256.25,
              numeratorUnits: ["in"], denominatorUnits: ["s"])));
    });

    test("can coerce its value to unitless", () {
      expect(value.coerceValue([], []), equals(24.6));
    });

    test("can coerce its value to compatible units", () {
      expect(value.coerceValue(["px"], ["ms"]), equals(24.6));
      expect(value.coerceValue(["in"], ["s"]), equals(256.25));
    });

    test("can't coerce its value to incompatible units", () {
      expect(() => value.coerceValue(["abc"], []), throwsSassScriptException);
    });

    test("can't convert its value to unitless", () {
      expect(() => value.convertValueToMatch(SassNumber(456)),
          throwsSassScriptException);
    });

    test("can convert its value to compatible units", () {
      expect(
          value.convertValueToMatch(SassNumber.withUnits(456,
              numeratorUnits: ["px"], denominatorUnits: ["ms"])),
          equals(24.6));
      expect(
          value.convertValueToMatch(SassNumber.withUnits(456,
              numeratorUnits: ["in"], denominatorUnits: ["s"])),
          equals(256.25));
    });

    test("can't convert its value to incompatible units", () {
      expect(() => value.convertValueToMatch(SassNumber(456, "abc")),
          throwsSassScriptException);
    });

    test("is incompatible with the numerator unit", () {
      expect(value.compatibleWithUnit("px"), isFalse);
    });

    test("is incompatible with the denominator unit", () {
      expect(value.compatibleWithUnit("ms"), isFalse);
    });

    test("equals the same number", () {
      expect(
          value,
          equalsWithHash(SassNumber.withUnits(24.6,
              numeratorUnits: ["px"], denominatorUnits: ["ms"])));
    });

    test("equals an equivalent number", () {
      expect(
          value,
          equalsWithHash(SassNumber.withUnits(256.25,
              numeratorUnits: ["in"], denominatorUnits: ["s"])));
    });

    test("doesn't equal a unitless number", () {
      expect(value, isNot(equals(SassNumber(24.6))));
    });

    test("doesn't equal a number with different units", () {
      expect(value, isNot(equals(SassNumber(24.6, "px"))));
      expect(value,
          isNot(equals(SassNumber.withUnits(24.6, denominatorUnits: ["ms"]))));
      expect(
          value,
          isNot(equals(SassNumber.withUnits(24.6,
              numeratorUnits: ["ms"], denominatorUnits: ["px"]))));
      expect(
          value,
          isNot(equals(SassNumber.withUnits(24.6,
              numeratorUnits: ["in"], denominatorUnits: ["s"]))));
    });
  });

  group("new SassNumber()", () {
    test("can create a unitless number", () {
      var number = SassNumber(123.456);
      expect(number.value, equals(123.456));
      expect(number.hasUnits, isFalse);
    });

    test("can create a number with a numerator unit", () {
      var number = SassNumber(123.456, "px");
      expect(number.value, equals(123.456));
      expect(number.hasUnit('px'), isTrue);
    });
  });

  group("new SassNumber.withUnits()", () {
    test("can create a unitless number", () {
      var number = SassNumber.withUnits(123.456);
      expect(number.value, equals(123.456));
      expect(number.hasUnits, isFalse);
    });

    test("can create a number with units", () {
      var number = SassNumber.withUnits(123.456,
          numeratorUnits: ["px", "em"], denominatorUnits: ["ms", "kHz"]);
      expect(number.value, equals(123.456));
      expect(number.numeratorUnits, equals(["px", "em"]));
      expect(number.denominatorUnits, equals(["ms", "kHz"]));
    });
  });
}
