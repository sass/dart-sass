// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:collection/collection.dart';
import 'package:node_interop/js.dart';
import 'package:sass/src/node/immutable.dart';
import 'package:sass/src/node/utils.dart';

import '../../value.dart';
import '../reflection.dart';

/// Check that [arg] is a valid argument to a calculation function.
void isCalculationValue(Object arg, {bool checkUnquoted = true}) {
  if (arg is! SassNumber &&
      arg is! SassString &&
      arg is! SassCalculation &&
      arg is! CalculationOperation &&
      arg is! CalculationInterpolation) {
    jsThrow(JsError('Argument must be one of '
        'SassNumber, SassString, SassCalculation, CalculationOperation, '
        'CalculationInterpolation'));
  }
  if (checkUnquoted && arg is SassString && arg.hasQuotes) {
    jsThrow(JsError('Argument must be unquoted SassString'));
  }
}

/// The JavaScript `SassCalculation` class.
final JSClass calculationClass = () {
  calc(Object argument) {
    isCalculationValue(argument);
    return SassCalculation.unsimplified('calc', [argument]);
  }

  min(Object arguments) {
    var argList = jsToDartList(arguments).cast<Object>();
    argList.forEach(isCalculationValue);
    return SassCalculation.unsimplified('min', argList);
  }

  max(Object arguments) {
    var argList = jsToDartList(arguments).cast<Object>();
    argList.forEach(isCalculationValue);
    return SassCalculation.unsimplified('max', argList);
  }

  clamp(Object min, [Object? value, Object? max]) {
    if (value == null && max != null) {
      jsThrow(JsError('`value` is undefined and `max` is not undefined'));
    }
    if ((value == null || max == null) &&
        !(min is SassString && min.text.startsWith('var(')) &&
        !(value is SassString && value.text.startsWith('var('))) {
      jsThrow(JsError(
          '`value` or `max` is undefined and neither `min` nor `value` is a SassString that begins with "var("'));
    }
    [min, value, max].whereNotNull().forEach(isCalculationValue);
    return SassCalculation.unsimplified(
        'clamp', [min, value, max].whereNotNull());
  }

  var jsClass =
      createJSClass('sass.SassCalculation', (Object self, [Object? _]) {
    jsThrow(JsError("new sass.SassCalculation() isn't allowed"));
  });

  // Static methods
  setProperty(jsClass, 'calc', allowInteropNamed('calc', calc));
  setProperty(jsClass, 'min', allowInteropNamed('min', min));
  setProperty(jsClass, 'max', allowInteropNamed('max', max));
  setProperty(jsClass, 'clamp', allowInteropNamed('clamp', clamp));

  jsClass.defineMethods({
    'assertCalculation': (SassCalculation self, [String? name]) => self,
  });

  jsClass.defineGetters({
    'name': (SassCalculation self) => self.name,
    'arguments': (SassCalculation self) => self.arguments,
  });

  getJSClass(SassCalculation.unsimplified('calc', [SassNumber(1)]))
      .injectSuperclass(jsClass);
  return jsClass;
}();

/// The JavaScript CalculationOperator class
final JSClass calculationOperatorClass = () {
  var jsClass = getJSClass(CalculationOperator.plus).superclass;
  setProperty(jsClass, 'plus', CalculationOperator.plus);
  setProperty(jsClass, 'minus', CalculationOperator.minus);
  setProperty(jsClass, 'times', CalculationOperator.times);
  setProperty(jsClass, 'dividedBy', CalculationOperator.dividedBy);
  return jsClass;
}();

/// The JavaScript CalculationOperation class
final JSClass calculationOperationClass = () {
  var jsClass = createJSClass('sass.CalculationOperation',
      (Object self, CalculationOperator operator, Object left, Object right) {
    isCalculationValue(left, checkUnquoted: false);
    isCalculationValue(right, checkUnquoted: false);
    return SassCalculation.operateInternal(operator, left, right,
        inMinMax: false, simplify: false);
  });

  jsClass.defineMethods({
    'equals': (CalculationOperation self, Object other) => self == other,
    'hashCode': (CalculationOperation self) => self.hashCode,
  });

  jsClass.defineGetters({
    'operator': (CalculationOperation self) => self.operator,
    'left': (CalculationOperation self) => self.left,
    'right': (CalculationOperation self) => self.right,
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

  jsClass.defineGetters({
    'value': (CalculationInterpolation self) => self.value,
  });

  getJSClass(CalculationInterpolation('')).injectSuperclass(jsClass);
  return jsClass;
}();
