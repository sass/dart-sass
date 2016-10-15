// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class NodeError {
  external String get message;
  external int get line;
  external int get column;
  external int get status;
  external String get file;

  external factory NodeError(
      {String message, int line, int column, int status, String file});
}
