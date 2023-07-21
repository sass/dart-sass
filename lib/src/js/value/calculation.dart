// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:node_interop/js.dart';
import 'package:sass/src/js/immutable.dart';
import 'package:sass/src/js/utils.dart';

import '../../value.dart';
import '../reflection.dart';

/// Check that [arg] is a valid argument to a calculation function.
void _assertCalculationValue(Object arg) => switch (arg) {
      SassNumber() ||
      SassString(hasQuotes: false) ||
      SassCalculation() ||
      CalculationOperation() ||
      CalculationInterpolation() =>
        null,
      _ => jsThrow(JsError(
          'Argument `$arg` must be one of SassNumber, unquoted SassString, '
          'SassCalculation, CalculationOperation, CalculationInterpolation')),
    };

/// Check that [arg] is an unquoted string or interpolation.
bool _isValidClampArg(Object? arg) => switch (arg) {
      CalculationInterpolation() || SassString(hasQuotes: false) => true,
      _ => false,
    };

/// The JavaScript `SassCalculation` class.
final JSClass calculationClass = () {
  var jsClass =
      createJSClass('sass.SassCalculation', (Object self, [Object? _]) {
    jsThrow(JsError("new sass.SassCalculation() isn't allowed"));
  });

  jsClass.defineStaticMethods({
    'calc': (Object argument) {
      _assertCalculationValue(argument);
      return SassCalculation.unsimplified('calc', [argument]);
    },
    'min': (Object arguments) {
      var argList = jsToDartList(arguments).cast<Object>();
      argList.forEach(_assertCalculationValue);
      return SassCalculation.unsimplified('min', argList);
    },
    'max': (Object arguments) {
      var argList = jsToDartList(arguments).cast<Object>();
      argList.forEach(_assertCalculationValue);
      return SassCalculation.unsimplified('max', argList);
    },
    'clamp': (Object min, [Object? value, Object? max]) {
      if ((value == null && !_isValidClampArg(min)) ||
          (max == null && ![min, value].any(_isValidClampArg))) {
        jsThrow(JsError('Expected at least one SassString or '
            'CalculationInterpolation in `${[
          min,
          value,
          max
        ].whereNotNull()}`'));
      }
      [min, value, max].whereNotNull().forEach(_assertCalculationValue);
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

/// The JavaScript `CalculationOperation` class.
final JSClass calculationOperationClass = () {
  var jsClass = createJSClass('sass.CalculationOperation',
      (Object self, String strOperator, Object left, Object right) {
    var operator = CalculationOperator.values
        .firstWhereOrNull((value) => value.operator == strOperator);
    if (operator == null) {
      jsThrow(JsError('Invalid operator: $strOperator'));
    }
    _assertCalculationValue(left);
    _assertCalculationValue(right);
    return SassCalculation.operateInternal(operator, left, right,
        inMinMax: false, simplify: false);
  });

  jsClass.defineMethods({
    'equals': (CalculationOperation self, Object other) => self == other,
    'hashCode': (CalculationOperation self) => self.hashCode,
  });

  jsClass.defineGetters({
    'operator': (CalculationOperation self) => self.operator.operator,
    'left': (CalculationOperation self) => self.left,
    'right': (CalculationOperation self) => self.right,
  });

  getJSClass(SassCalculation.operateInternal(
          CalculationOperator.plus, SassNumber(1), SassNumber(1),
          inMinMax: false, simplify: false))
      .injectSuperclass(jsClass);
  return jsClass;
}();

/// The JavaScript `CalculationInterpolation` class.
final JSClass calculationInterpolationClass = () {
  var jsClass = createJSClass('sass.CalculationInterpolation',
      (Object self, String value) => CalculationInterpolation(value));

  jsClass.defineMethods({
    'equals': (CalculationInterpolation self, Object other) => self == other,
    'hashCode': (CalculationInterpolation self) => self.hashCode,
  });

  jsClass.defineGetters({
    'value': (CalculationInterpolation self) => self.value,
  });

  getJSClass(CalculationInterpolation('')).injectSuperclass(jsClass);
  return jsClass;
}();
