// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'utils.dart';

@JS()
@anonymous
class RenderError {
  external String get message;
  external int get line;
  external int get column;
  external int get status;
  external String get file;

  external factory RenderError._(
      {String message, int line, int column, int status, String file});
}

RenderError newRenderError(String message,
    {int line, int column, int status, String file}) {
  var error = new RenderError._(
      message: message, line: line, column: column, status: status, file: file);
  setToString(error, () => "Error: $message");
  return error;
}
