// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

extension type Chokidar._(JSObject _) implements JSObject {
  external ChokidarWatcher watch(String path, ChokidarOptions options);
}

extension type ChokidarOptions._(JSObject _) implements JSObject {
  external bool? get usePolling;

  external ChokidarOptions({bool? usePolling});
}

extension type ChokidarWatcher._(JSObject _) implements JSObject {
  external void on(String event, JSFunction callback);
  external void close();
}

/// The Chokidar module.
///
/// See [the docs on npm](https://www.npmjs.com/package/chokidar).
@JS()
external Chokidar get chokidar;
