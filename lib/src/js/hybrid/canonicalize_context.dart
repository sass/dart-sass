// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:web/web.dart';

import '../../importer/canonicalize_context.dart';
import '../../util/nullable.dart';

extension type JSCanonicalizeContext._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    CanonicalizeContext(null, false).toJS.constructor.defineGetters({
      'fromImport': (JSCanonicalizeContext self) => self.toDart.fromImport.toJS,
      'containingUrl':
          (JSCanonicalizeContext self) => self.toDart.containingUrl?.toJS,
    });
  }

  CanonicalizeContext get toDart => this as CanonicalizeContext;
}

extension CanonicalizeContextToJS on CanonicalizeContext {
  JSCanonicalizeContext get toJS => this as JSCanonicalizeContext;
}
