// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:js/js.dart';
import 'package:source_span/source_span.dart';

import '../exception.dart';
import '../util/path.dart';

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
class _Stdin {
  external String read();

  external void on(String event, void callback([object]));
}

@JS()
class _SystemError {
  external String get message;
  external String get code;
  external String get syscall;
  external String get path;
}

@JS()
class _Process {
  external String get platform;
  external String cwd();
}

class FileSystemException {
  final String message;
  final String path;

  FileSystemException._(this.message, this.path);
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

@JS("process")
external _Process get _process;

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
    var systemError = error as _SystemError;
    throw new FileSystemException._(
        _cleanErrorMessage(systemError), systemError.path);
  }
}

Future<String> readStdin() async {
  var completer = new Completer<String>();
  String contents;
  var innerSink = new StringConversionSink.withCallback((String result) {
    contents = result;
    completer.complete(contents);
  });
  // Node defaults all buffers to 'utf8'.
  var sink = UTF8.decoder.startChunkedConversion(innerSink);
  _stdin.on('data', allowInterop(([chunk]) {
    assert(chunk != null);
    sink.add(chunk as List<int>);
  }));
  _stdin.on('end', allowInterop(([_]) {
    // Callback for 'end' receives no args.
    assert(_ == null);
    sink.close();
  }));
  _stdin.on('error', allowInterop(([e]) {
    assert(e != null);
    stderr.writeln('Failed to read from stdin');
    stderr.writeln(e);
    completer.completeError(e);
  }));
  return completer.future;
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

@JS("process.stdin")
external _Stdin get _stdin;

bool get hasTerminal => _hasTerminal ?? false;

bool get isWindows => _process.platform == 'win32';

String get currentPath => _process.cwd();

@JS("process.stdout.isTTY")
external bool get _hasTerminal;

@JS("process.exitCode")
external int get exitCode;

@JS("process.exitCode")
external set exitCode(int code);
