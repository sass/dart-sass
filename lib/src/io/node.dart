// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:watcher/watcher.dart';

import '../exception.dart';
import '../node/chokidar.dart';

@JS()
class _FS {
  external Object readFileSync(String path, [String encoding]);
  external void writeFileSync(String path, String data);
  external bool existsSync(String path);
  external void mkdirSync(String path);
  external _Stat statSync(String path);
  external void unlinkSync(String path);
  external List<Object> readdirSync(String path);
}

@JS()
class _Stat {
  external bool isFile();
  external bool isDirectory();
  external _Date get mtime;
}

@JS()
class _Date {
  external int getTime();
}

@JS()
class _Stderr {
  external void write(String text);
}

@JS()
class _Stdin {
  external String read();

  external void on(String event, void callback([Object object]));
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
  external Object get env;
  external String cwd();
}

class FileSystemException {
  final String message;
  final String path;

  FileSystemException._(this.message, this.path);

  String toString() => "${p.prettyUri(p.toUri(path))}: $message";
}

class Stderr {
  final _Stderr _stderr;

  Stderr(this._stderr);

  void write(Object object) => _stderr.write(object.toString());

  void writeln([Object object]) {
    _stderr.write("${object ?? ''}\n");
  }

  void flush() {}
}

@JS("fs")
external _FS get _fs;

@JS("process")
external _Process get _process;

String readFile(String path) {
  // TODO(nweiz): explicitly decode the bytes as UTF-8 like we do in the VM when
  // it doesn't cause a substantial performance degradation for large files. See
  // also dart-lang/sdk#25377.
  var contents = _readFile(path, 'utf8') as String;
  if (!contents.contains("�")) return contents;

  var sourceFile = SourceFile.fromString(contents, url: p.toUri(path));
  for (var i = 0; i < contents.length; i++) {
    if (contents.codeUnitAt(i) != 0xFFFD) continue;
    throw SassException("Invalid UTF-8.", sourceFile.location(i).pointSpan());
  }

  // This should be unreachable.
  return contents;
}

/// Wraps `fs.readFileSync` to throw a [FileSystemException].
Object _readFile(String path, [String encoding]) =>
    _systemErrorToFileSystemException(() => _fs.readFileSync(path, encoding));

void writeFile(String path, String contents) =>
    _systemErrorToFileSystemException(() => _fs.writeFileSync(path, contents));

void deleteFile(String path) =>
    _systemErrorToFileSystemException(() => _fs.unlinkSync(path));

Future<String> readStdin() async {
  var completer = Completer<String>();
  String contents;
  var innerSink = StringConversionSink.withCallback((String result) {
    contents = result;
    completer.complete(contents);
  });
  // Node defaults all buffers to 'utf8'.
  var sink = utf8.decoder.startChunkedConversion(innerSink);
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

bool fileExists(String path) {
  return _systemErrorToFileSystemException(() {
    // `existsSync()` is faster than `statSync()`, but it doesn't clarify
    // whether the entity in question is a file or a directory. Since false
    // negatives are much more common than false positives, it works out in our
    // favor to check this first.
    if (!_fs.existsSync(path)) return false;

    try {
      return _fs.statSync(path).isFile();
    } catch (error) {
      var systemError = error as _SystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

bool dirExists(String path) {
  return _systemErrorToFileSystemException(() {
    // `existsSync()` is faster than `statSync()`, but it doesn't clarify
    // whether the entity in question is a file or a directory. Since false
    // negatives are much more common than false positives, it works out in our
    // favor to check this first.
    if (!_fs.existsSync(path)) return false;

    try {
      return _fs.statSync(path).isDirectory();
    } catch (error) {
      var systemError = error as _SystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

void ensureDir(String path) {
  return _systemErrorToFileSystemException(() {
    try {
      _fs.mkdirSync(path);
    } catch (error) {
      var systemError = error as _SystemError;
      if (systemError.code == 'EEXIST') return;
      if (systemError.code != 'ENOENT') rethrow;
      ensureDir(p.dirname(path));
      _fs.mkdirSync(path);
    }
  });
}

Iterable<String> listDir(String path, {bool recursive = false}) {
  return _systemErrorToFileSystemException(() {
    if (!recursive) {
      return _fs
          .readdirSync(path)
          .map((child) => p.join(path, child as String))
          .where((child) => !dirExists(child));
    } else {
      Iterable<String> list(String parent) =>
          _fs.readdirSync(parent).expand((child) {
            var path = p.join(parent, child as String);
            return dirExists(path) ? list(path) : [path];
          });

      return list(path);
    }
  });
}

DateTime modificationTime(String path) =>
    _systemErrorToFileSystemException(() => DateTime.fromMillisecondsSinceEpoch(
        _fs.statSync(path).mtime.getTime()));

String getEnvironmentVariable(String name) =>
    getProperty(_process.env, name) as String;

/// Runs callback and converts any [_SystemError]s it throws into
/// [FileSystemException]s.
T _systemErrorToFileSystemException<T>(T callback()) {
  try {
    return callback();
  } catch (error) {
    var systemError = error as _SystemError;
    throw FileSystemException._(
        _cleanErrorMessage(systemError), systemError.path);
  }
}

@JS("process.stderr")
external _Stderr get _stderr;

final stderr = Stderr(_stderr);

@JS("process.stdin")
external _Stdin get _stdin;

bool get hasTerminal => _hasTerminal ?? false;

bool get isWindows => _process.platform == 'win32';

bool get isMacOS => _process.platform == 'darwin';

bool get isNode => true;

// Node seems to support ANSI escapes on all terminals.
bool get supportsAnsiEscapes => hasTerminal;

String get currentPath => _process.cwd();

@JS("process.stdout.isTTY")
external bool get _hasTerminal;

@JS("process.exitCode")
external int get exitCode;

// TODO(nweiz): remove this ignore when dart-lang/sdk#39250 is fixed.
// ignore: inference_failure_on_function_return_type
@JS("process.exitCode")
external set exitCode(int code);

Future<Stream<WatchEvent>> watchDir(String path, {bool poll = false}) {
  var watcher = chokidar.watch(
      path, ChokidarOptions(disableGlobbing: true, usePolling: poll));

  // Don't assign the controller until after the ready event fires. Otherwise,
  // Chokidar will give us a bunch of add events for files that already exist.
  StreamController<WatchEvent> controller;
  watcher
    ..on(
        'add',
        allowInterop((String path, [void _]) =>
            controller?.add(WatchEvent(ChangeType.ADD, path))))
    ..on(
        'change',
        allowInterop((String path, [void _]) =>
            controller?.add(WatchEvent(ChangeType.MODIFY, path))))
    ..on(
        'unlink',
        allowInterop((String path) =>
            controller?.add(WatchEvent(ChangeType.REMOVE, path))))
    ..on('error', allowInterop((Object error) => controller?.addError(error)));

  var completer = Completer<Stream<WatchEvent>>();
  watcher.on('ready', allowInterop(() {
    controller = StreamController<WatchEvent>(onCancel: () {
      watcher.close();
    });
    completer.complete(controller.stream);
  }));

  return completer.future;
}
