// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

/// Check that [arg] is a valid argument to a calculation function.
void _assertCalculationValue(Object arg) => switch (arg) {
      SassNumber() ||
      SassString(hasQuotes: false) ||
      SassCalculation() ||
      CalculationOperation() ||
      CalculationInterpolation() =>
        null,
      _ => JSError.throwLikeJS(
          JSError(
            'Argument `$arg` must be one of SassNumber, unquoted SassString, '
            'SassCalculation, CalculationOperation, CalculationInterpolation',
          ),
        ),
    };

/// Check that [arg] is an unquoted string or interpolation.
bool _isValidClampArg(Object? arg) => switch (arg) {
      CalculationInterpolation() || SassString(hasQuotes: false) => true,
      _ => false,
    };

extension type JSSassCalculation._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSSassCalculation> jsClass = () {
    var jsClass = JSClass<JSSassCalculation>('sass.SassCalculation', (JSSassCalculation self, [JSAny? _]) {
    JSError.throwLikeJS(JSError("new sass.SassCalculation() isn't allowed."));
  }.toJS)..defineStaticMethods({
    'calc': (JSObject argument) {
      _assertCalculationValue(argument);
      return SassCalculation.unsimplified('calc', [argument]).toJS;
    }.toJS,
    'min': (JSObject arguments) {
      var argList = arguments.toDartList<JSObject>();
      argList.forEach(_assertCalculationValue);
      return SassCalculation.unsimplified('min', argList).toJS;
    }.toJS,
    'max': (JSObject arguments) {
      var argList = arguments.toDartList<JSObject>();
      argList.forEach(_assertCalculationValue);
      return SassCalculation.unsimplified('max', argList).toJS;
    }.toJS,
    'clamp': (JSObject min, [JSObject? value, JSObject? max]) {
      if ((value == null && !_isValidClampArg(min)) ||
          (max == null && ![min, value].any(_isValidClampArg))) {
        JSError.throwLikeJS(
          JSError(
            'Expected at least one SassString or '
            'CalculationInterpolation in `${[min, value, max].nonNulls}`',
          ),
        );
      }
      [min, value, max].nonNulls.forEach(_assertCalculationValue);
      return SassCalculation.unsimplified('clamp', [min, value, max].nonNulls).toJS;
    }.toJS,
  })
  ..defineMethod(
    'assertCalculation'.toJS, ((JSSassCalculation self, [String? name]) => self).toJS,
  )..defineGetters({
      'name': ((JSSassCalculation self) => self.name).toJS,
      'arguments': ((JSSassCalculation self) => self.toJS.arguments.cast<JSValue>().toJSImmutable).toJS,
  });

  SassCalculation.unsimplified('calc', [SassNumber(1)]).toJS.constructor.injectSuperclass(jsClass);

  return jsClass;
}();

  SassCalculation get toDart => this as SassCalculation;
}

extension SassCalculationToJS on SassCalculation {
  JSSassCalculation get toJS => this as JSSassCalculation;
}

extension type JSCalculationOperation._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSCalculationOperation> jsClass = () {
    var jsClass = JSClass<JSCalculationOperation>('sass.CalculationOperation', (JSCalculationOperation self, String strOperator, JSObject left, JSObject right) {
    var operator = CalculationOperator.values.firstWhereOrNull(
      (value) => value.operator == strOperator,
    );
    if (operator == null) {
      JSError.throwLikeJS(JSError('Invalid operator: $strOperator'));
    }
    _assertCalculationValue(left);
    _assertCalculationValue(right);
    return SassCalculation.operateInternal(
      operator,
      left,
      right,
      inLegacySassFunction: null,
      simplify: false,
      warn: null,
    );
  }.toJS)..defineMethods({
    'equals': ((JSCalculationOperation self, JSAny? other) => self.toDart == other).toJS,
    'hashCode': ((JSCalculationOperation self) => self.toDart.hashCode).toJS,
  })..defineGetters({
    'operator': ((JSCalculationOperation self) => self.toDart.operator.operator).toJS,
    'left': ((JSCalculationOperation self) => self.toDart.left as JSObject).toJS,
    'right': ((JSCalculationOperation self) => self.toDart.right as JSObject).toJS,
  });

  SassCalculation.operateInternal(
      CalculationOperator.plus,
      SassNumber(1),
      SassNumber(1),
      inLegacySassFunction: null,
      simplify: false,
      warn: null,
    ).toJS.constructor.injectSuperclass(jsClass);

  return jsClass;
}();

  JSCalculationOperation get toDart => this as JSCalculationOperation;
}

extension CalculationOperationToJS on CalculationOperation {
  JSCalculationOperation get toJS => this as JSCalculationOperation;
}

extension type JSCalculationInterpolation._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSCalculationInterpolation> jsClass = () {
    var jsClass = JSClass<JSCalculationInterpolation>('sass.CalculationInterpolation', ((JSCalculationInterpolation self, String value) => CalculationInterpolation(value)).toJS)
    ..defineMethods({
    'equals': ((JSCalculationInterpolation self, JSAny? other) => self.toDart == other).toJS,
    'hashCode': ((JSCalculationInterpolation self) => self.toDart.hashCode).toJS,
  })..defineGetter('value'.toJS, ((JSCalculationInterpolation self) => self.toDart.value).toJS);

  CalculationInterpolation('').toJS.constructor.injectSuperclass(jsClass);

  return jsClass;
}();

  JSCalculationInterpolation get toDart => this as JSCalculationInterpolation;
}

extension CalculationInterpolationToJS on CalculationInterpolation {
  JSCalculationInterpolation get toJS => this as JSCalculationInterpolation;
}
