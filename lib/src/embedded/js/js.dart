// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

extension JSTypedArrayExtension on JSTypedArray {
  external JSArrayBuffer get buffer;
}

extension JSArrayExtension<T extends JSAny?> on JSArray<T> {
  external JSArray<T> slice([int start, int end]);
}
