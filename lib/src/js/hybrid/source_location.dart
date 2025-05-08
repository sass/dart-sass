// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:source_span/source_span.dart';

import '../../util/span.dart';

extension SourceLocationToJS on SourceLocation {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    bogusSourceSpan.start.toJS.constructor.defineGetters({
      'line': (UnsafeDartWrapper<SourceLocation> self) => self.toDart.line.toJS,
      'column': (UnsafeDartWrapper<SourceLocation> self) =>
          self.toDart.column.toJS,
    });
  }

  UnsafeDartWrapper<SourceLocation> get toJS => toUnsafeWrapper;
}
