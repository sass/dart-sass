// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../exception.dart';

@JS()
class _FS {
  external readFileSync(String path, [String encoding]);

  external bool existsSync(String path);
}

@JS()
class _Stderr {
  external void write(String text);
}

@JS()
class _SystemError {
  external String get message;
  external String get code;
  external String get syscall;
  external String get path;
}

class FileSystemException {
  final String message;

  FileSystemException._(this.message);
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

String readFile(String path) {
  // TODO(nweiz): explicitly decode the bytes as UTF-8 like we do in the VM when
  // it doesn't cause a substantial performance degradation for large files. See
  // also dart-lang/sdk#25377.
  var contents = _readFile(path, 'utf8') as String;
  if (!contents.contains("�")) return contents;

  var sourceFile = new SourceFile.fromString(contents, url: p.toUri(path));
  for (var i = 0; i < contents.length; i++) {
    if (contents.codeUnitAt(i) != 0xFFFD) continue;
    throw new SassException(
        "Invalid UTF-8.", sourceFile.location(i).pointSpan());
  }

  // This should be unreachable.
  return contents;
}

/// Wraps `fs.readFileSync` to throw a [FileSystemException].
_readFile(String path, [String encoding]) {
  try {
    return _fs.readFileSync(path, encoding);
  } catch (error) {
    throw new FileSystemException._(_cleanErrorMessage(error as _SystemError));
  }
}

/// Cleans up a Node system error's message.
String _cleanErrorMessage(_SystemError error) {
  // The error message is of the form "$code: $text, $syscall '$path'". We just
  // want the text.
  return error.message.substring("${error.code}: ".length,
      error.message.length - ", ${error.syscall} '${error.path}'".length);
}

bool fileExists(String path) => _fs.existsSync(path);

bool dirExists(String path) => _fs.existsSync(path);

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
