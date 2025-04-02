// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'js.dart';

@JS('process.argv')
external JSArray<JSAny?> get _argv;

(String, JSArray<JSString>) workerEntryPoint() {
  return ((_argv[1]! as JSString).toDart, _argv.slice(2) as JSArray<JSString>);
}
