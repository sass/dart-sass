// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'array.dart';

@JS()
@anonymous
class NodeSourceMap {
  external num get version;
  external String get sourceRoot;
  external JSArray get sources;
  external JSArray get names;
  external String get mappings;
  external String? get file;
  external JSArray? get sourcesContent;
}

@JS()
@anonymous
class NodeCompileResult {
  external String get css;
  external NodeSourceMap? get sourceMap;
  external JSArray get loadedUrls;

  external factory NodeCompileResult(
      {required String css,
      NodeSourceMap? sourceMap,
      required JSArray loadedUrls});
}
