// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../ast/sass/statement/loud_comment.dart';
import '../../util/span.dart';
import 'span.dart';

extension type JSLoudCommentExpression._(JSObject _) implements JSObject {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    LoudCommentExpression(LoudCommentAnything(Interpolation.bogus))
        .toJS
        .constructor
        .defineGetter('span'.toJS,
            ((JSLoudCommentExpression self) => self.toDart.span.toJS).toJS);
  }

  LoudCommentExpression get toDart => this as LoudCommentExpression;
}

extension LoudCommentExpressionToJS on LoudCommentExpression {
  JSLoudCommentExpression get toJS => this as JSLoudCommentExpression;
}
