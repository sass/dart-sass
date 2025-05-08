// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';

extension type RenderError._(JSError _) implements JSError {
  external String formatted;
  external int? line;
  external int? column;
  external String? file;
  external int? status;

  factory RenderError(
    String message,
    StackTrace stackTrace, {
    int? line,
    int? column,
    String? file,
    int? status,
  }) {
    var error = RenderError._(JSError(message));
    error.formatted = 'Error: $message';
    if (line != null) error.line = line;
    if (column != null) error.column = column;
    if (file != null) error.file = file;
    if (status != null) error.status = status;
    error.stack = stackTrace.toString();
    return error;
  }
}
