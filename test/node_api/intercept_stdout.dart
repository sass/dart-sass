// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:js/js.dart';

typedef _InterceptStdout = void Function() Function(
    String Function(String), String Function(String));

@JS('require')
external _InterceptStdout _require(String name);

final _interceptStdout = _require("intercept-stdout");

/// All output that would be printed to stderr is instead piped through that
/// stream as long as it has a listener.
///
/// Note that the piped text is not necessarily separated by lines.
Stream<String> interceptStderr() {
  void Function() unhook;
  StreamController<String> controller;
  controller = StreamController(onListen: () {
    unhook = _interceptStdout(null, allowInterop((text) {
      controller.add(text);
      return "";
    }));
  }, onCancel: () {
    unhook();
  });

  return controller.stream;
}
