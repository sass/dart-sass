// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:cli_pkg/js.dart';
import 'package:js/js.dart';
import 'package:node_interop/fs.dart';
import 'package:node_interop/node_interop.dart' hide process;
import 'package:node_interop/util.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:watcher/watcher.dart';

import '../exception.dart';
import '../js/chokidar.dart';

@JS('process')
external final Process? _nodeJsProcess; // process is null in the browser

/// The Node.JS [Process] global variable.
///
/// This value is `null` when running the script is not run from Node.JS
Process? get _process => isNodeJs ? _nodeJsProcess : null;

class FileSystemException {
  final String message;
  final String path;

  FileSystemException._(this.message, this.path);

  String toString() => "${p.prettyUri(p.toUri(path))}: $message";
}

void safePrint(Object? message) {
  if (_process case var process?) {
    process.stdout.write("${message ?? ''}\n");
  } else {
    console.log(message ?? '');
  }
}

void printError(Object? message) {
  if (_process case var process?) {
    process.stderr.write("${message ?? ''}\n");
  } else {
    console.error(message ?? '');
  }
}

String readFile(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("readFile() is only supported on Node.js");
  }
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
Object? _readFile(String path, [String? encoding]) =>
    _systemErrorToFileSystemException(() => fs.readFileSync(path, encoding));

void writeFile(String path, String contents) {
  if (!isNodeJs) {
    throw UnsupportedError("writeFile() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(
      () => fs.writeFileSync(path, contents));
}

void deleteFile(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("deleteFile() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() => fs.unlinkSync(path));
}

Future<String> readStdin() async {
  var process = _process;
  if (process == null) {
    throw UnsupportedError("readStdin() is only supported on Node.js");
  }
  var completer = Completer<String>();
  String contents;
  var innerSink = StringConversionSink.withCallback((String result) {
    contents = result;
    completer.complete(contents);
  });
  // Node defaults all buffers to 'utf8'.
  var sink = utf8.decoder.startChunkedConversion(innerSink);
  process.stdin.on('data', allowInterop(([Object? chunk]) {
    sink.add(chunk as List<int>);
  }));
  process.stdin.on('end', allowInterop(([Object? arg]) {
    // Callback for 'end' receives no args.
    assert(arg == null);
    sink.close();
  }));
  process.stdin.on('error', allowInterop(([Object? e]) {
    printError('Failed to read from stdin');
    printError(e);
    completer.completeError(e!);
  }));
  return completer.future;
}

/// Cleans up a Node system error's message.
String _cleanErrorMessage(JsSystemError error) {
  // The error message is of the form "$code: $text, $syscall '$path'". We just
  // want the text.
  return error.message.substring("${error.code}: ".length,
      error.message.length - ", ${error.syscall} '${error.path}'".length);
}

bool fileExists(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("fileExists() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    // `existsSync()` is faster than `statSync()`, but it doesn't clarify
    // whether the entity in question is a file or a directory. Since false
    // negatives are much more common than false positives, it works out in our
    // favor to check this first.
    if (!fs.existsSync(path)) return false;

    try {
      return fs.statSync(path).isFile();
    } catch (error) {
      var systemError = error as JsSystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

bool dirExists(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("dirExists() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    // `existsSync()` is faster than `statSync()`, but it doesn't clarify
    // whether the entity in question is a file or a directory. Since false
    // negatives are much more common than false positives, it works out in our
    // favor to check this first.
    if (!fs.existsSync(path)) return false;

    try {
      return fs.statSync(path).isDirectory();
    } catch (error) {
      var systemError = error as JsSystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

void ensureDir(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("ensureDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    try {
      fs.mkdirSync(path);
    } catch (error) {
      var systemError = error as JsSystemError;
      if (systemError.code == 'EEXIST') return;
      if (systemError.code != 'ENOENT') rethrow;
      ensureDir(p.dirname(path));
      fs.mkdirSync(path);
    }
  });
}

Iterable<String> listDir(String path, {bool recursive = false}) {
  if (!isNodeJs) {
    throw UnsupportedError("listDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    if (!recursive) {
      return fs
          .readdirSync(path)
          .map((child) => p.join(path, child as String))
          .where((child) => !dirExists(child));
    } else {
      Iterable<String> list(String parent) =>
          fs.readdirSync(parent).expand((child) {
            var path = p.join(parent, child as String);
            return dirExists(path) ? list(path) : [path];
          });

      return list(path);
    }
  });
}

DateTime modificationTime(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("modificationTime() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() =>
      DateTime.fromMillisecondsSinceEpoch(fs.statSync(path).mtime.getTime()));
}

String? getEnvironmentVariable(String name) {
  var env = _process?.env;
  return env == null ? null : getProperty(env as Object, name) as String?;
}

/// Runs callback and converts any [JsSystemError]s it throws into
/// [FileSystemException]s.
T _systemErrorToFileSystemException<T>(T callback()) {
  try {
    return callback();
  } catch (error) {
    if (error is! JsSystemError) rethrow;
    throw FileSystemException._(_cleanErrorMessage(error), error.path);
  }
}

/// Ignore `invalid_null_aware_operator` error, because [process.stdout.isTTY]
/// from `node_interop` declares `isTTY` as always non-nullably available, but
/// in practice it's undefined if stdout isn't a TTY.
/// See: https://github.com/pulyaevskiy/node-interop/issues/93
bool get hasTerminal => _process?.stdout.isTTY == true;

bool get isWindows => _process?.platform == 'win32';

bool get isMacOS => _process?.platform == 'darwin';

// Node seems to support ANSI escapes on all terminals.
bool get supportsAnsiEscapes => hasTerminal;

int get exitCode => _process?.exitCode ?? 0;

set exitCode(int code) => _process?.exitCode = code;

Future<Stream<WatchEvent>> watchDir(String path, {bool poll = false}) {
  if (!isNodeJs) {
    throw UnsupportedError("watchDir() is only supported on Node.js");
  }
  var watcher = chokidar.watch(path, ChokidarOptions(usePolling: poll));

  // Don't assign the controller until after the ready event fires. Otherwise,
  // Chokidar will give us a bunch of add events for files that already exist.
  StreamController<WatchEvent>? controller;
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
    // dart-lang/sdk#45348
    var stream = (controller = StreamController<WatchEvent>(onCancel: () {
      watcher.close();
    }))
        .stream;
    completer.complete(stream);
  }));

  return completer.future;
}
