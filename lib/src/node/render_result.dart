// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:js/js.dart';

@JS('Buffer.from')
external _buffer(String source, String encoding);

@JS()
@anonymous
class RenderResult {
  external Uint8List get css;

  external factory RenderResult._({css});
}

RenderResult newRenderResult(String css) =>
    new RenderResult._(css: _buffer(css, 'utf8'));
