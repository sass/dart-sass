// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:source_span/source_span.dart';

import '../../util/span.dart';

extension FileLocationToJS on FileLocation {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    bogusSpan.start.toJS.constructor.defineGetters({
      'line': (UnsafeDartWrapper<FileLocation> self) => self.toDart.line.toJS,
      'column': (UnsafeDartWrapper<FileLocation> self) =>
          self.toDart.column.toJS,
    });
  }

  UnsafeDartWrapper<FileLocation> get toJS => toUnsafeWrapper;
}
