// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class RenderOptions {
  external String get file;
  external String get data;
  external bool get indentedSyntax;
  external String get indentType;
  external dynamic get indentWidth;
  external String get linefeed;

  external factory RenderOptions(
      {String file,
      String data,
      bool indentedSyntax,
      String indentType,
      indentWidth,
      String linefeed});
}
