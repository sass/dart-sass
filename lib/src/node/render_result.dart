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
  external RenderResultStats get stats;

  external factory RenderResult._({css, RenderResultStats stats});
}

@JS()
@anonymous
class RenderResultStats {
  external String get entry;
  external int get start;
  external int get end;
  external int get duration;
  external List<String> get includedFiles;

  external factory RenderResultStats._(
      {String entry,
      int start,
      int end,
      int duration,
      List<String> includedFiles});
}

RenderResult newRenderResult(String css,
        {String entry,
        int start,
        int end,
        int duration,
        List<String> includedFiles}) =>
    new RenderResult._(
        css: css == null ? null : _buffer(css, 'utf8'),
        stats: new RenderResultStats._(
            entry: entry,
            start: start,
            end: end,
            duration: duration,
            includedFiles: includedFiles));
