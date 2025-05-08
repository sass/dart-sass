// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression/supports.dart';
import '../../ast/sass/supports_condition/anything.dart';
import '../../ast/sass/interpolation.dart';
import '../../util/span.dart';
import 'file_span.dart';

extension SupportsExpressionToJS on SupportsExpression {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    SupportsExpression(SupportsAnything(Interpolation.bogus, bogusSpan))
        .toJS
        .constructor
        .defineGetter(
            'span'.toJS,
            (UnsafeDartWrapper<SupportsExpression> self) =>
                self.toDart.span.toJS);
  }

  UnsafeDartWrapper<SupportsExpression> get toJS => toUnsafeWrapper;
}
