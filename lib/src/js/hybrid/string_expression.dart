// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../ast/sass/expression/string.dart';
import 'span.dart';

extension type JSStringExpression._(JSObject _) implements JSObject {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    StringExpression(Interpolation.bogus).toJS.constructor
      .defineGetter('span'.toJS, ((JSStringExpression self) => self.toDart.span.toJS).toJS);
  }

  StringExpression get toDart => this as StringExpression;
}

extension StringExpressionToJS on StringExpression {
  JSStringExpression get toJS => this as JSStringExpression;
}
