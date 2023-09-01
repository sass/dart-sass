// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  group("new SassCalculation", () {
    late Value value;
    setUp(() => value = SassCalculation.unsimplified('calc', [SassNumber(1)]));

    test("is a calculation", () {
      expect(value.assertCalculation(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.tryMap(), isNull);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group('SassCalculation simplifies', () {
    test('calc()', () {
      expect(SassCalculation.calc(SassNumber(1)).assertNumber(),
          equals(SassNumber(1)));
    });

    test('min()', () {
      expect(SassCalculation.min([SassNumber(1), SassNumber(2)]).assertNumber(),
          equals(SassNumber(1)));
    });

    test('max()', () {
      expect(SassCalculation.max([SassNumber(1), SassNumber(2)]).assertNumber(),
          equals(SassNumber(2)));
    });

    test('clamp()', () {
      expect(
          SassCalculation.clamp(SassNumber(1), SassNumber(2), SassNumber(3))
              .assertNumber(),
          equals(SassNumber(2)));
    });

    test('operations', () {
      expect(
          SassCalculation.calc(SassCalculation.operate(
                  CalculationOperator.plus,
                  SassCalculation.operate(
                      CalculationOperator.minus,
                      SassCalculation.operate(
                          CalculationOperator.times,
                          SassCalculation.operate(CalculationOperator.dividedBy,
                              SassNumber(5), SassNumber(2)),
                          SassNumber(3)),
                      SassNumber(4)),
                  SassNumber(5)))
              .assertNumber(),
          equals(SassNumber(8.5)));
    });

    test('interpolation', () {
        var result = SassCalculation.calc(CalculationInterpolation('1 + 2'))
              .assertCalculation();
      expect(result.name, equals('calc'));
      expect(result.arguments[0], equals(SassString('(1 + 2)')));
    });
  });
}
