// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('process.exitCode')
external int? get _exitCode;
int get exitCode => _exitCode ?? 0;

@JS('process.exitCode')
external set exitCode(int code);

@JS('process.exit')
external void exit([int code]);

@JS()
extension type _ReadStream(JSObject _) implements JSObject {
  external void destroy();
  external void on(String type, JSFunction listener);
}

@JS('process.stdin')
external _ReadStream get _stdin;

@JS()
extension type _WriteStream(JSObject _) implements JSObject {
  external void write(JSUint8Array chunk);
}

@JS('process.stdout')
external _WriteStream get _stdout;

Stream<List<int>> get stdin {
  var controller = StreamController<Uint8List>(
      onCancel: () {
        _stdin.destroy();
      },
      sync: true);
  _stdin.on(
      'data',
      (JSUint8Array chunk) {
        controller.sink.add(chunk.toDart);
      }.toJS);
  _stdin.on(
      'end',
      () {
        controller.sink.close();
      }.toJS);
  _stdin.on(
      'error',
      (JSObject e) {
        controller.sink.addError(e);
      }.toJS);
  return controller.stream;
}

StreamSink<List<int>> get stdout {
  var controller = StreamController<Uint8List>(sync: true);
  controller.stream.listen((buffer) {
    _stdout.write(buffer.toJS);
  });
  return controller.sink;
}
