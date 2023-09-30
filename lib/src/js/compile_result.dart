// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'array.dart';

@JS()
@anonymous
class NodeCompileResult {
  external String get css;
  external Object? get sourceMap;
  external JSArray get loadedUrls;

  external factory NodeCompileResult(
      {required String css, Object? sourceMap, required JSArray loadedUrls});
}
