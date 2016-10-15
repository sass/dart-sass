// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
class _FS {
  external String readFileSync(String path, String encoding);

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

String readFile(String path) => _fs.readFileSync(path, 'utf8');

bool fileExists(String path) => _fs.existsSync(path);

@JS("process.stderr")
external _Stderr get _stderr;

final stderr = new Stderr(_stderr);

@JS("process.exit")
external int exit(int exitCode);
