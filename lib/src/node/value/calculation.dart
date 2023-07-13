// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:node_interop/js.dart';
import 'package:sass/src/node/immutable.dart';
import 'package:sass/src/node/utils.dart';

import '../../value.dart';
import '../reflection.dart';

/// Check that [arg] is a valid argument to a calculation function.
void assertCalculationValue(Object arg) {
  if (arg is! SassNumber &&
      arg is! SassString &&
      arg is! SassCalculation &&
      arg is! CalculationOperation &&
      arg is! CalculationInterpolation) {
    jsThrow(JsError('Argument `$arg` must be one of '
        'SassNumber, SassString, SassCalculation, CalculationOperation, '
        'CalculationInterpolation'));
  }
  if (arg is SassString && arg.hasQuotes) {
    jsThrow(JsError('Argument `$arg` must be unquoted SassString'));
  }
}

/// Check that [arg] is an unquoted string or interpolation
bool isValidClampArg(Object? arg) => ((arg is CalculationInterpolation) ||
    (arg is SassString && !arg.hasQuotes));

/// The JavaScript `SassCalculation` class.
final JSClass calculationClass = () {
  var jsClass =
      createJSClass('sass.SassCalculation', (Object self, [Object? _]) {
    jsThrow(JsError("new sass.SassCalculation() isn't allowed"));
  });

  jsClass.defineStaticMethods({
    'calc': (Object argument) {
      assertCalculationValue(argument);
      return SassCalculation.unsimplified('calc', [argument]);
    },
    'min': (Object arguments) {
      var argList = jsToDartList(arguments).cast<Object>();
      argList.forEach(assertCalculationValue);
      return SassCalculation.unsimplified('min', argList);
    },
    'max': (Object arguments) {
      var argList = jsToDartList(arguments).cast<Object>();
      argList.forEach(assertCalculationValue);
      return SassCalculation.unsimplified('max', argList);
    },
    'clamp': (Object min, [Object? value, Object? max]) {
      if ((value == null && !isValidClampArg(min)) ||
          (max == null) && !([min, value]).any(isValidClampArg)) {
        jsThrow(JsError('Expected at least one SassString or '
            'CalculationInterpolation in `${[
          min,
          value,
          max
        ].whereNotNull()}`'));
      }
      [min, value, max].whereNotNull().forEach(assertCalculationValue);
      return SassCalculation.unsimplified(
          'clamp', [min, value, max].whereNotNull());
    }
  });

  jsClass.defineMethods({
    'assertCalculation': (SassCalculation self, [String? name]) => self,
  });

  jsClass.defineGetters({
    // The `name` getter is included by default by `createJSClass`
    'arguments': (SassCalculation self) => ImmutableList(self.arguments),
  });

  getJSClass(SassCalculation.unsimplified('calc', [SassNumber(1)]))
      .injectSuperclass(jsClass);
  return jsClass;
}();

/// The JavaScript CalculationOperation class
final JSClass calculationOperationClass = () {
  var jsClass = createJSClass('sass.CalculationOperation',
      (Object self, String strOperator, Object left, Object right) {
    var operator = CalculationOperator.values
        .firstWhereOrNull((value) => value.operator == strOperator);
    if (operator == null) {
      jsThrow(JsError('Invalid operator: $strOperator'));
    }
    assertCalculationValue(left);
    assertCalculationValue(right);
    return SassCalculation.operateInternal(operator, left, right,
        inMinMax: false, simplify: false);
  });

  jsClass.defineMethods({
    'equals': (CalculationOperation self, Object other) => self == other,
    'hashCode': (CalculationOperation self) => self.hashCode,
  });

  jsClass.defineGetters({
    'operator': (CalculationOperation self) => self.operator.operator,
  });

  getJSClass(SassCalculation.operateInternal(
          CalculationOperator.plus, SassNumber(1), SassNumber(1),
          inMinMax: false, simplify: false))
      .injectSuperclass(jsClass);
  return jsClass;
}();

/// The JavaScript CalculationInterpolation class
final JSClass calculationInterpolationClass = () {
  var jsClass = createJSClass('sass.CalculationInterpolation',
      (Object self, String value) => CalculationInterpolation(value));

  jsClass.defineMethods({
    'equals': (CalculationInterpolation self, Object other) => self == other,
    'hashCode': (CalculationInterpolation self) => self.hashCode,
  });

  getJSClass(CalculationInterpolation('')).injectSuperclass(jsClass);
  return jsClass;
}();
