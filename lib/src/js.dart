// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'js/exception.dart';
import 'js/exports.dart';
import 'js/compile.dart';
import 'js/legacy.dart';
import 'js/legacy/types.dart';
import 'js/legacy/value.dart';
import 'js/logger.dart';
import 'js/source_span.dart';
import 'js/utils.dart';
import 'js/value.dart';
import 'value.dart';

/// The entrypoint for the JavaScript module.
///
/// This sets up exports that can be called from JS.
void main() {
  exports.compile = allowInteropNamed('sass.compile', compile);
  exports.compileString =
      allowInteropNamed('sass.compileString', compileString);
  exports.compileAsync = allowInteropNamed('sass.compileAsync', compileAsync);
  exports.compileStringAsync =
      allowInteropNamed('sass.compileStringAsync', compileStringAsync);
  exports.Value = valueClass;
  exports.SassBoolean = booleanClass;
  exports.SassArgumentList = argumentListClass;
  exports.SassCalculation = calculationClass;
  exports.CalculationOperation = calculationOperationClass;
  exports.CalculationInterpolation = calculationInterpolationClass;
  exports.SassColor = colorClass;
  exports.SassFunction = functionClass;
  exports.SassMixin = mixinClass;
  exports.SassList = listClass;
  exports.SassMap = mapClass;
  exports.SassNumber = numberClass;
  exports.SassString = stringClass;
  exports.sassNull = sassNull;
  exports.sassTrue = sassTrue;
  exports.sassFalse = sassFalse;
  exports.Exception = exceptionClass;
  exports.Logger = LoggerNamespace(
      silent: JSLogger(
          warn: allowInteropNamed('sass.Logger.silent.warn', (_, __) {}),
          debug: allowInteropNamed('sass.Logger.silent.debug', (_, __) {})));

  exports.info =
      "dart-sass\t${const String.fromEnvironment('version')}\t(Sass Compiler)\t"
      "[Dart]\n"
      "dart2js\t${const String.fromEnvironment('dart-version')}\t"
      "(Dart Compiler)\t[Dart]";

  updateSourceSpanPrototype();

  // Legacy API
  exports.render = allowInteropNamed('sass.render', render);
  exports.renderSync = allowInteropNamed('sass.renderSync', renderSync);

  exports.types = Types(
      Boolean: legacyBooleanClass,
      Color: legacyColorClass,
      List: legacyListClass,
      Map: legacyMapClass,
      Null: legacyNullClass,
      Number: legacyNumberClass,
      String: legacyStringClass,
      Error: jsErrorClass);
  exports.NULL = sassNull;
  exports.TRUE = sassTrue;
  exports.FALSE = sassFalse;
}
