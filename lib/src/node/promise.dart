// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js';

import 'package:js/js.dart';

/// Describes the native JavaScript `Promise` global.
@JS()
class Promise<T> {
  external Promise(void executor(void resolve(T result), Function reject));
}

/// Converts a Future to a JavaScript Promise.
Promise<T> futureToPromise<T>(Future<T> future) {
  return Promise<T>(allowInterop((resolve, reject) =>
      future.then(resolve, onError: reject)));
}
