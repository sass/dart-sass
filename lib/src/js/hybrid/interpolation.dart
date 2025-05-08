// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../util/span.dart';

extension type JSInterpolation._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    Interpolation.bogus.toJS.constructor.defineGetter(
        'asPlain'.toJS, (JSInterpolation self) => self.toDart.asPlain?.toJS);
  }

  Interpolation get toDart => this as Interpolation;
}

extension InterpolationToJS on Interpolation {
  JSInterpolation get toJS => this as JSInterpolation;
}
