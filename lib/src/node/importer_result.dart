// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class NodeImporterResult {
  external String get file;
  external String get contents;

  external factory NodeImporterResult({String file, String contents});
}
