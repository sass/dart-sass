// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class RenderContext {
  external RenderContextOptions get options;
  external bool? get fromImport;

  external factory RenderContext(
      {required RenderContextOptions options, bool? fromImport});
}

@JS()
@anonymous
class RenderContextOptions {
  external String? get file;
  external String? get data;
  external String get includePaths;
  external int get precision;
  external int get style;
  external int get indentType;
  external int get indentWidth;
  external String get linefeed;
  external RenderContext get context;
  external set context(RenderContext value);
  external RenderContextResult get result;

  external factory RenderContextOptions(
      {String? file,
      String? data,
      required String includePaths,
      required int precision,
      required int style,
      required int indentType,
      required int indentWidth,
      required String linefeed,
      required RenderContextResult result});
}

@JS()
@anonymous
class RenderContextResult {
  external RenderContextResultStats get stats;

  external factory RenderContextResult(
      {required RenderContextResultStats stats});
}

@JS()
@anonymous
class RenderContextResultStats {
  external int get start;
  external String get entry;

  external factory RenderContextResultStats(
      {required int start, required String entry});
}
