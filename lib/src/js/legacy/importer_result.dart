// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

extension type NodeImporterResult._(JSObject _) implements JSObject {
  external String? get file;
  external JSAny? get contents;

  external NodeImporterResult({String? file, String? contents});
}
