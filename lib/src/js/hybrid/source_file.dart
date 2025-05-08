// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:source_span/source_span.dart';

extension SourceFileToJS on SourceFile {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    SourceFile.fromString('').toJS.constructor
      ..defineMethod(
        'getText'.toJS,
        ((UnsafeDartWrapper<SourceFile> self, int start, [int? end]) =>
            self.toDart.getText(start, end)).toJSCaptureThis,
      )
      ..defineGetter('codeUnits'.toJS,
          (UnsafeDartWrapper<SourceFile> self) => self.toDart.codeUnits.toJS);
  }

  UnsafeDartWrapper<SourceFile> get toJS => toUnsafeWrapper;
}
