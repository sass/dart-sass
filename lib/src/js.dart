// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import 'js/compile.dart';
import 'js/compiler/async.dart';
import 'js/compiler/sync.dart';
import 'js/deprecation.dart';
import 'js/exports.dart';
import 'js/hybrid/canonicalize_context.dart';
import 'js/hybrid/file_location.dart';
import 'js/hybrid/file_span.dart';
import 'js/hybrid/node_importer.dart';
import 'js/hybrid/source_span.dart';
import 'js/hybrid/value.dart';
import 'js/hybrid/version.dart';
import 'js/legacy.dart';
import 'js/legacy/types.dart';
import 'js/legacy/value.dart';
import 'js/logger.dart';
import 'js/parser.dart';
import 'js/sass_exception.dart';
import 'value.dart';

@JS('Error')
external JSClass<JSError> _jsErrorClass;

/// The entrypoint for the JavaScript module.
///
/// This sets up exports that can be called from JS.
void main() {
  exports.compile = compile.toJS..name = 'sass.compile';
  exports.compileString = compileString.toJS..name = 'sass.compileString';
  exports.compileAsync = compileAsync.toJS..name = 'sass.compileAsync';
  exports.compileStringAsync = compileStringAsync.toJS
    ..name = 'sass.compileStringAsync';
  exports.initCompiler = (() => JSCompiler()).toJS..name = 'sass.initCompiler';
  exports.initAsyncCompiler = (() => Future.sync(() => JSAsyncCompiler()).toJS)
      .toJS
    ..name = 'sass.initAsyncCompiler';
  exports.Compiler = JSCompiler.jsClass;
  exports.AsyncCompiler = JSAsyncCompiler.jsClass;
  exports.Value = ValueToJS.jsClass;
  exports.SassBoolean = SassBooleanToJS.jsClass;
  exports.SassArgumentList = SassArgumentListToJS.jsClass;
  exports.SassCalculation = SassCalculationToJS.jsClass;
  exports.CalculationOperation = CalculationOperationToJS.jsClass;
  exports.CalculationInterpolation = CalculationInterpolationToJS.jsClass;
  exports.SassColor = SassColorToJS.jsClass;
  exports.SassFunction = SassFunctionToJS.jsClass;
  exports.SassMixin = SassMixinToJS.jsClass;
  exports.SassList = SassListToJS.jsClass;
  exports.SassMap = SassMapToJS.jsClass;
  exports.SassNumber = SassNumberToJS.jsClass;
  exports.SassString = SassStringToJS.jsClass;
  exports.sassNull = sassNull.toJS;
  exports.sassTrue = sassTrue.toJS;
  exports.sassFalse = sassFalse.toJS;
  exports.Exception = JSSassException.jsClass;
  exports.Logger = LoggerNamespace(
    silent: JSLogger(
      warn: (JSAny? _, JSAny? __) {}.toJS..name = 'sass.Logger.silent.warn',
      debug: (JSAny? _, JSAny? __) {}.toJS..name = 'sass.Logger.silent.debug',
    ),
  );
  exports.NodePackageImporter = NodePackageImporterToJS.jsClass;
  exports.deprecations = JSDeprecation.all;
  exports.Version = VersionToJS.jsClass;
  exports.loadParserExports_ = loadParserExports.toJS;

  exports.info =
      "dart-sass\t${const String.fromEnvironment('version')}\t(Sass Compiler)\t"
      "[Dart]\n"
      "dart2js\t${const String.fromEnvironment('dart-version')}\t"
      "(Dart Compiler)\t[Dart]";

  CanonicalizeContextToJS.updatePrototype();
  FileSpanToJS.updatePrototype();
  FileLocationToJS.updatePrototype();
  SourceSpanToJS.updatePrototype();

  // Legacy API
  exports.render = render.toJS..name = 'sass.render';
  exports.renderSync = renderSync.toJS..name = 'sass.renderSync';

  exports.types = Types(
    Boolean: JSSassLegacyBoolean.jsClass,
    Color: JSSassLegacyColor.jsClass,
    List: JSSassLegacyList.jsClass,
    Map: JSSassLegacyMap.jsClass,
    Null: JSSassLegacyNull.jsClass,
    Number: JSSassLegacyNumber.jsClass,
    String: JSSassLegacyString.jsClass,
    Error: _jsErrorClass,
  );
  exports.NULL = sassNull.toJS;
  exports.TRUE = sassTrue.toJS;
  exports.FALSE = sassFalse.toJS;
}
