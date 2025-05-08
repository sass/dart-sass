// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../value.dart';
import 'deprecation.dart';
import 'hybrid/value.dart';
import 'legacy/types.dart';
import 'logger.dart';

@anonymous
extension type Exports._(JSObject _) implements JSObject {
  external set renderSync(JSFunction function);
  external set compileString(JSFunction function);
  external set compileStringAsync(JSFunction function);
  external set compile(JSFunction function);
  external set compileAsync(JSFunction function);
  external set initCompiler(JSFunction function);
  external set initAsyncCompiler(JSFunction function);
  external set Compiler(JSClass function);
  external set AsyncCompiler(JSClass function);
  external set info(String info);
  external set Exception(JSClass function);
  external set Logger(LoggerNamespace namespace);
  external set NodePackageImporter(JSClass function);
  external set deprecations(JSRecord<JSDeprecation> object);
  external set Version(JSClass version);

  // Value APIs
  external set Value(JSClass<JSValue> function);
  external set SassArgumentList(JSClass<JSSassArgumentList> function);
  external set SassCalculation(JSClass<JSSassCalculation> function);
  external set CalculationOperation(JSClass<JSCalculationOperation> function);
  external set CalculationInterpolation(JSClass<JSCalculationInterpolation> function);
  external set SassBoolean(JSClass<JSSassBoolean> function);
  external set SassColor(JSClass<JSSassColor> function);
  external set SassFunction(JSClass<JSSassFunction> function);
  external set SassMixin(JSClass<JSSassMixin> mixin);
  external set SassList(JSClass<JSSassList> function);
  external set SassMap(JSClass<JSSassMap> function);
  external set SassNumber(JSClass<JSSassNumber> function);
  external set SassString(JSClass<JSSassString> function);
  external set sassNull(JSValue sassNull);
  external set sassTrue(JSSassBoolean sassTrue);
  external set sassFalse(JSSassBoolean sassFalse);

  // Legacy APIs
  external set run_(JSFunction function);
  external set render(JSFunction function);
  external set types(Types types);
  external set NULL(JSValue sassNull);
  external set TRUE(JSSassBoolean sassTrue);
  external set FALSE(JSSassBoolean sassFalse);

  // `sass-parser` APIs
  external set loadParserExports_(JSFunction function);
}

@anonymous
extension type LoggerNamespace._(JSObject _) implements JSObject {
  external JSLogger get silent;

  external LoggerNamespace({required JSLogger silent});
}

@JS()
external Exports get exports;
