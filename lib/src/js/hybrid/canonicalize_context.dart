// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:web/web.dart';

import '../../importer/canonicalize_context.dart';

extension CanonicalizeContextToJS on CanonicalizeContext {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    CanonicalizeContext(null, false).toJS.constructor.defineGetters({
      'fromImport': (UnsafeDartWrapper<CanonicalizeContext> self) =>
          self.toDart.fromImport.toJS,
      'containingUrl': (UnsafeDartWrapper<CanonicalizeContext> self) =>
          self.toDart.containingUrl?.toJS,
    });
  }

  UnsafeDartWrapper<CanonicalizeContext> get toJS => toUnsafeWrapper;
}
