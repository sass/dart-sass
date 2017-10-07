// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'utils.dart';

@JS()
@anonymous
class RenderError {
  external String get message;
  external String get formatted;
  external int get line;
  external int get column;
  external String get file;
  external int get status;

  external factory RenderError._(
      {String message,
      String formatted,
      int line,
      int column,
      String file,
      int status});
}

RenderError newRenderError(String message,
    {String formatted, int line, int column, String file, int status}) {
  var error = new RenderError._(
      message: message,
      formatted: formatted,
      line: line,
      column: column,
      file: file,
      status: status);
  setToString(error, () => "Error: $message");
  return error;
}
