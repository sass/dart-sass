// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'render_context.dart';
import 'render_result.dart';

@JS()
@anonymous
class RenderContextOptions {
  external String get file;
  external String get data;
  external String get includePaths;
  external int get precision;
  external int get style;
  external int get indentType;
  external int get indentWidth;
  external String get linefeed;
  external RenderContext get context;
  external set context(RenderContext value);
  external RenderResult get result;

  external factory RenderContextOptions(
      {String file,
      String data,
      String includePaths,
      int precision,
      int style,
      int indentType,
      int indentWidth,
      String linefeed,
      RenderResult result});
}
