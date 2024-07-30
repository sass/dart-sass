// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../importer/node_package.dart';
import '../logger.dart';
import 'fiber.dart';

@JS()
@anonymous
class RenderOptions {
  external String? get file;
  external String? get data;
  external Object? get importer;
  external NodePackageImporter? get pkgImporter;
  external Object? get functions;
  external List<Object /* String */ >? get includePaths;
  external bool? get indentedSyntax;
  external bool? get omitSourceMapUrl;
  external String? get outFile;
  external String? get outputStyle;
  external String? get indentType;
  external Object? get indentWidth;
  external String? get linefeed;
  external FiberClass? get fiber;
  external Object? get sourceMap;
  external bool? get sourceMapContents;
  external bool? get sourceMapEmbed;
  external String? get sourceMapRoot;
  external bool? get quietDeps;
  external List<Object /*Deprecation|String|Version*/ >? get fatalDeprecations;
  external List<Object /*Deprecation|String*/ >? get futureDeprecations;
  external List<Object /*Deprecation|String*/ >? get silenceDeprecations;
  external bool? get verbose;
  external bool? get charset;
  external JSLogger? get logger;

  external factory RenderOptions(
      {String? file,
      String? data,
      Object? importer,
      NodePackageImporter? pkgImporter,
      Object? functions,
      List<String>? includePaths,
      bool? indentedSyntax,
      bool? omitSourceMapUrl,
      String? outFile,
      String? outputStyle,
      String? indentType,
      Object? indentWidth,
      String? linefeed,
      FiberClass? fiber,
      Object? sourceMap,
      bool? sourceMapContents,
      bool? sourceMapEmbed,
      String? sourceMapRoot,
      bool? quietDeps,
      List<Object>? fatalDeprecations,
      List<Object>? futureDeprecations,
      List<Object>? silenceDeprecations,
      bool? verbose,
      bool? charset,
      JSLogger? logger});
}
