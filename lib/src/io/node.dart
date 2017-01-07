// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:js/js.dart';

@JS()
class _FS {
  external readFileSync(String path, [String encoding]);

  external bool existsSync(String path);
}

@JS()
class _Stderr {
  external void write(String text);
}

class Stderr {
  final _Stderr _stderr;

  Stderr(this._stderr);

  void write(object) => _stderr.write(object.toString());

  void writeln([object]) {
    if (object != null) _stderr.write("$object\n");
  }

  void flush() {}
}

@JS("require")
external _FS _require(String name);

final _fs = _require("fs");

List<int> readFileAsBytes(String path) => _fs.readFileSync(path) as Uint8List;

String readFileAsString(String path) =>
    _fs.readFileSync(path, 'utf8') as String;

bool fileExists(String path) => _fs.existsSync(path);

@JS("process.stderr")
external _Stderr get _stderr;

final stderr = new Stderr(_stderr);

bool get hasTerminal => _hasTerminal ?? false;

@JS("process.stdout.isTTY")
external bool get _hasTerminal;

@JS("process.exitCode")
external int get exitCode;

@JS("process.exitCode")
external set exitCode(int code);
