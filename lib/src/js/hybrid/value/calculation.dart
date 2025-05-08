// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:collection/collection.dart';
import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../value.dart';

/// Check that [arg] is a valid argument to a calculation function.
Object _assertCalculationValue(JSAny arg) => switch (arg) {
      SassNumber() ||
      SassString(hasQuotes: false) ||
      SassCalculation() ||
      CalculationOperation() ||
      CalculationInterpolation() =>
        arg,
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

extension SassCalculationToJS on SassCalculation {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassCalculation>> jsClass = () {
    // TODO - dart-lang/sdk#61249: define this inline when `Never` works as a JS
    // interop type.
    void constructor([JSAny? _]) {
      JSError.throwLikeJS(JSError("new sass.SassCalculation() isn't allowed."));
    }

    var jsClass = JSClass<UnsafeDartWrapper<SassCalculation>>(constructor.toJS)
      ..defineStaticMethods({
        'calc': ((JSAny argument) => SassCalculation.unsimplified(
            'calc', [_assertCalculationValue(argument)]).toJS).toJS,
        'min': ((JSObject arguments) => SassCalculation.unsimplified('min',
                arguments.toDartList<JSAny>().map(_assertCalculationValue))
            .toJS).toJS,
        'max': ((JSObject arguments) => SassCalculation.unsimplified('max',
                arguments.toDartList<JSAny>().map(_assertCalculationValue))
            .toJS).toJS,
        'clamp': (JSAny min, [JSAny? value, JSAny? max]) {
          if ((value == null && !_isValidClampArg(min)) ||
              (max == null && ![min, value].any(_isValidClampArg))) {
            JSError.throwLikeJS(
              JSError(
                'Expected at least one SassString or '
                'CalculationInterpolation in `${[min, value, max].nonNulls}`',
              ),
            );
          }
          return SassCalculation.unsimplified('clamp',
                  [min, value, max].nonNulls.map(_assertCalculationValue))
              .toJS;
        }.toJS,
      })
      ..defineMethod(
        'assertCalculation'.toJS,
        ((UnsafeDartWrapper<SassCalculation> self, [String? name]) => self)
            .toJSCaptureThis,
      )
      ..defineGetter(
        'arguments'.toJS,
        (UnsafeDartWrapper<SassCalculation> self) => self.toDart.arguments
            .cast<UnsafeDartWrapper<Value>>()
            .toJSImmutable,
      );

    SassCalculation.unsimplified('calc', [SassNumber(1)])
        .toJS
        .constructor
        .injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassCalculation> get toJS => toUnsafeWrapper;
}

extension CalculationOperationToJS on CalculationOperation {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<CalculationOperation>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<CalculationOperation>>(
        (String strOperator, JSAny left, JSAny right) {
      var operator = CalculationOperator.values.firstWhereOrNull(
        (value) => value.operator == strOperator,
      );
      if (operator == null) {
        JSError.throwLikeJS(JSError('Invalid operator: $strOperator'));
      }
      return (SassCalculation.operateInternal(
        operator,
        _assertCalculationValue(left),
        _assertCalculationValue(right),
        inLegacySassFunction: null,
        simplify: false,
        warn: null,
      ) as CalculationOperation)
          .toJS;
    }.toJS)
      ..defineMethods({
        'equals':
            ((UnsafeDartWrapper<CalculationOperation> self, JSAny? other) =>
                switch (other.asClassOrNull(CalculationOperationToJS.jsClass)) {
                  var operation? => self.toDart == operation.toDart,
                  _ => false
                }).toJSCaptureThis,
        'hashCode': ((UnsafeDartWrapper<CalculationOperation> self) =>
            self.toDart.hashCode).toJS,
      })
      ..defineGetters({
        'operator': (UnsafeDartWrapper<CalculationOperation> self) =>
            self.toDart.operator.operator.toJS,
        'left': (UnsafeDartWrapper<CalculationOperation> self) =>
            self.toDart.left as JSAny,
        'right': (UnsafeDartWrapper<CalculationOperation> self) =>
            self.toDart.right as JSAny,
      });

    (SassCalculation.operateInternal(
      CalculationOperator.plus,
      SassNumber(1),
      SassNumber(1),
      inLegacySassFunction: null,
      simplify: false,
      warn: null,
    ) as CalculationOperation)
        .toJS
        .constructor
        .injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<CalculationOperation> get toJS => toUnsafeWrapper;
}

extension CalculationInterpolationToJS on CalculationInterpolation {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<CalculationInterpolation>> jsClass =
      () {
    var jsClass = JSClass<UnsafeDartWrapper<CalculationInterpolation>>(
        ((String value) => CalculationInterpolation(value).toJS).toJS)
      ..defineMethods({
        'equals': ((UnsafeDartWrapper<CalculationInterpolation> self,
                JSAny? other) =>
            switch (other.asClassOrNull(CalculationInterpolationToJS.jsClass)) {
              var interpolation? => self.toDart == interpolation.toDart,
              _ => false
            }).toJSCaptureThis,
        'hashCode': ((UnsafeDartWrapper<CalculationInterpolation> self) =>
            self.toDart.hashCode).toJSCaptureThis,
      })
      ..defineGetter(
          'value'.toJS,
          (UnsafeDartWrapper<CalculationInterpolation> self) =>
              self.toDart.value.toJS);

    CalculationInterpolation('').toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<CalculationInterpolation> get toJS => toUnsafeWrapper;
}
