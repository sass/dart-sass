// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'importer.dart';
import 'logger.dart';
import 'url.dart';

@JS()
@anonymous
class CompileOptions {
  external bool? get alertAscii;
  external bool? get alertColor;
  external List<String>? get loadPaths;
  external bool? get quietDeps;
  external String? get style;
  external bool? get verbose;
  external bool? get charset;
  external bool? get sourceMap;
  external bool? get sourceMapIncludeSources;
  external JSLogger? get logger;
  external List<Object?>? get importers;
  external Object? get functions;
  external List<Object?>? get fatalDeprecations;
  external List<Object?>? get silenceDeprecations;
  external List<Object?>? get futureDeprecations;
}

@JS()
@anonymous
class CompileStringOptions extends CompileOptions {
  external String? get syntax;
  external JSUrl? get url;
  external JSImporter? get importer;
}
