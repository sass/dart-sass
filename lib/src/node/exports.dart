// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'package:js/js.dart';

import '../value.dart' as value;
import 'legacy/types.dart';
import 'logger.dart';
import 'reflection.dart';

@JS()
class Exports {
  external set renderSync(Function function);
  external set compileString(Function function);
  external set compileStringAsync(Function function);
  external set compile(Function function);
  external set compileAsync(Function function);
  external set info(String info);
  external set Exception(JSClass function);
  external set Logger(LoggerNamespace namespace);

  // Value APIs
  external set Value(JSClass function);
  external set SassArgumentList(JSClass function);
  external set SassBoolean(JSClass function);
  external set SassColor(JSClass function);
  external set SassFunction(JSClass function);
  external set SassList(JSClass function);
  external set SassMap(JSClass function);
  external set SassNumber(JSClass function);
  external set SassString(JSClass function);
  external set sassNull(value.Value sassNull);
  external set sassTrue(value.SassBoolean sassTrue);
  external set sassFalse(value.SassBoolean sassFalse);

  // Legacy APIs
  external set run_(Function function);
  external set render(Function function);
  external set types(Types types);
  external set NULL(value.Value sassNull);
  external set TRUE(value.SassBoolean sassTrue);
  external set FALSE(value.SassBoolean sassFalse);
}

@JS()
@anonymous
class LoggerNamespace {
  external NodeLogger get silent;

  external factory LoggerNamespace({required NodeLogger silent});
}

@JS()
external Exports get exports;
