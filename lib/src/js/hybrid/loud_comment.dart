// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../ast/sass/statement/loud_comment.dart';
import '../../util/span.dart';
import 'file_span.dart';

extension type JSLoudComment._(JSObject _) implements JSObject {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    LoudComment(Interpolation.bogus).toJS.constructor.defineGetter(
        'span'.toJS, (JSLoudComment self) => self.toDart.span.toJS);
  }

  LoudComment get toDart => this as LoudComment;
}

extension LoudCommentToJS on LoudComment {
  JSLoudComment get toJS => this as JSLoudComment;
}
