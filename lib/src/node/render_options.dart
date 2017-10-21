// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'render_context.dart';
import 'render_result.dart';

@JS()
@anonymous
class RenderOptions {
  external String get file;
  external String get data;
  external dynamic get importer;
  external List<String> get includePaths;
  external bool get indentedSyntax;
  external String get outputStyle;
  external String get indentType;
  external dynamic get indentWidth;
  external String get linefeed;

  // Only used in "this" in importer callbacks.
  external int get precision;
  external int get style;
  external RenderContext get context;
  external RenderResult get result;

  external factory RenderOptions(
      {String file,
      String data,
      importer,
      List<String> includePaths,
      bool indentedSyntax,
      String outputStyle,
      String indentType,
      indentWidth,
      String linefeed,
      int precision,
      int style,
      RenderContext context,
      RenderResult result});
}
