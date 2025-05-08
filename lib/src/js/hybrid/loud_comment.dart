// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../ast/sass/statement/loud_comment.dart';
import 'file_span.dart';

extension LoudCommentToJS on LoudComment {
  /// Modstringies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    LoudComment(Interpolation.bogus).toJS.constructor.defineGetter('span'.toJS,
        (UnsafeDartWrapper<LoudComment> self) => self.toDart.span.toJS);
  }

  UnsafeDartWrapper<LoudComment> get toJS => toUnsafeWrapper;
}
