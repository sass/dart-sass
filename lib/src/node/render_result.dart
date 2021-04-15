// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:js/js.dart';

@JS()
@anonymous
class RenderResult {
  external Uint8List get css;
  external Uint8List? get map;
  external RenderResultStats get stats;

  external factory RenderResult(
      {required Uint8List css,
      Uint8List? map,
      required RenderResultStats stats});
}

@JS()
@anonymous
class RenderResultStats {
  external String get entry;
  external int get start;
  external int get end;
  external int get duration;
  external List<Object /* String */ > get includedFiles;

  external factory RenderResultStats(
      {required String entry,
      required int start,
      required int end,
      required int duration,
      required List<String> includedFiles});
}
