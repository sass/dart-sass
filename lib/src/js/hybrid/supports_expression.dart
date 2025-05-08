// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/expression/supports.dart';
import '../../ast/sass/interpolation.dart';
import '../../util/span.dart';
import 'span.dart';

extension type JSSupportsExpression._(JSObject _) implements JSObject {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    SupportsExpression(SupportsAnything(Interpolation.bogus, bogusSpan))
        .toJS
        .constructor
        .defineGetter('span'.toJS,
            ((JSSupportsExpression self) => self.toDart.span.toJS).toJS);
  }

  SupportsExpression get toDart => this as SupportsExpression;
}

extension SupportsExpressionToJS on SupportsExpression {
  JSSupportsExpression get toJS => this as JSSupportsExpression;
}
