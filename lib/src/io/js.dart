// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:cli_pkg/js.dart';
import 'package:js_core/js_core.dart';
import 'package:node_interop/fs.dart';
import 'package:node_interop/node_interop.dart' hide process;
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:watcher/watcher.dart';
import 'package:web/web.dart';

import '../exception.dart';
import '../js/chokidar.dart';
import '../js/parcel_watcher.dart';

@JS('process')
external final ProcessModule? _nodeJsProcess; // process is null in the browser

/// The Node.JS [Process] global variable.
///
/// This value is `null` when running the script is not run from Node.JS
ProcessModule? get _process => isNodeJs ? _nodeJsProcess : null;

class FileSystemException {
  final String message;
  final String path;

  FileSystemException._(this.message, this.path);

  String toString() => "${p.prettyUri(p.toUri(path))}: $message";
}

void safePrint(Object? message) {
  console.log((message?.toString() ?? '').toJS);
}

void printError(Object? message) {
  console.error((message?.toString() ?? '').toJS);
}

String readFile(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("readFile() is only supported on Node.js");
  }
  // TODO(nweiz): explicitly decode the bytes as UTF-8 like we do in the VM when
  // it doesn't cause a substantial performance degradation for large files. See
  // also dart-lang/sdk#25377.
  var contents = _systemErrorToFileSystemException(
      () => fs.readFileAsStringSync(path.toJS, 'utf8'));
  if (!contents.contains("�")) return contents;

  var sourceFile = SourceFile.fromString(contents, url: p.toUri(path));
  for (var i = 0; i < contents.length; i++) {
    if (contents.codeUnitAt(i) != 0xFFFD) continue;
    throw SassException("Invalid UTF-8.", sourceFile.location(i).pointSpan());
  }

  // This should be unreachable.
  return contents;
}

void writeFile(String path, String contents) {
  if (!isNodeJs) {
    throw UnsupportedError("writeFile() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(
    () => fs.writeFileSync(path.toJS, contents.toJS),
  );
}

void deleteFile(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("deleteFile() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() => fs.unlinkSync(path.toJS));
}

Future<String> readStdin() async {
  var process = _process;
  if (process == null) {
    throw UnsupportedError("readStdin() is only supported on Node.js");
  }

  try {
    return await utf8.decodeStream(
        process.standardInput.toDartStream.map((buffer) => buffer.toDart));
  } catch (error) {
    printError('Failed to read from stdin');
    printError(error);
    rethrow;
  }
}

/// Cleans up a Node system error's message.
String _cleanErrorMessage(NodeSystemError error) {
  // The error message is of the form "$code: $text, $syscall '$path'". We just
  // want the text.
  return error.message.substring(
    "${error.code}: ".length,
    error.message.length - ", ${error.systemCall} '${error.path}'".length,
  );
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
    if (!fs.existsSync(path.toJS)) return false;

    try {
      return fs.statSync(path.toJS).isFile;
    } catch (error) {
      var systemError = error as NodeSystemError;
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
    if (!fs.existsSync(path.toJS)) return false;

    try {
      return fs.statSync(path.toJS).isDir;
    } catch (error) {
      var systemError = error as NodeSystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

bool linkExists(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("linkExists() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() {
    try {
      return fs.statLinkSync(path.toJS).isSymbolicLink;
    } catch (error) {
      var systemError = error as NodeSystemError;
      if (systemError.code == 'ENOENT') return false;
      rethrow;
    }
  });
}

void ensureDir(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("ensureDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(
      () => fs.makeDirRecursiveSync(path.toJS));
}

Iterable<String> listDir(String path, {bool recursive = false}) {
  if (!isNodeJs) {
    throw UnsupportedError("listDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() => fs
      .readDirSync(path.toJS, recursive: recursive)
      .toDart
      .map((child) => p.join(path, child))
      .where((child) => !dirExists(child)));
}

String realpath(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("listDir() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(() => fs.realPathSync(path.toJS));
}

DateTime modificationTime(String path) {
  if (!isNodeJs) {
    throw UnsupportedError("modificationTime() is only supported on Node.js");
  }
  return _systemErrorToFileSystemException(
    () => fs.statSync(path.toJS).modificationTime.toDart,
  );
}

String? getEnvironmentVariable(String name) {
  var env = _process?.env;
  return env == null ? null : env[name]?.toDart;
}

/// Runs callback and converts any [JsSystemError]s it throws into
/// [FileSystemException]s.
T _systemErrorToFileSystemException<T>(T callback()) {
  try {
    return callback();
  } catch (error) {
    if (error is! JSObject) rethrow;
    if (!error.hasProperty('code'.toJS).toDart) rethrow;
    var systemError = error as NodeSystemError;
    throw FileSystemException._(
        _cleanErrorMessage(systemError), systemError.path!);
  }
}

bool get hasTerminal => _process?.standardOutput.isTty ?? false;

bool get isWindows => _process?.platform == 'win32';

bool get isMacOS => _process?.platform == 'darwin';

// Node seems to support ANSI escapes on all terminals.
bool get supportsAnsiEscapes => hasTerminal;

int get exitCode => _process?.exitCode ?? 0;

set exitCode(int code) => _process?.exitCode = code;

Future<Stream<WatchEvent>> watchDir(String path, {bool poll = false}) async {
  if (!isNodeJs) {
    throw UnsupportedError("watchDir() is only supported on Node.js");
  }

  // Don't assign the controller until after the ready event fires. Otherwise,
  // Chokidar will give us a bunch of add events for files that already exist.
  StreamController<WatchEvent>? controller;
  if (parcelWatcher case var parcel? when !poll) {
    var subscription = await parcel.subscribe(path, (
      Object? error,
      List<ParcelWatcherEvent> events,
    ) {
      if (error != null) {
        controller?.addError(error);
      } else {
        for (var event in events) {
          switch (event.type) {
            case 'create':
              controller?.add(WatchEvent(ChangeType.ADD, event.path));
            case 'update':
              controller?.add(WatchEvent(ChangeType.MODIFY, event.path));
            case 'delete':
              controller?.add(WatchEvent(ChangeType.REMOVE, event.path));
          }
        }
      }
    });

    return (controller = StreamController<WatchEvent>(
      onCancel: () {
        subscription.unsubscribe();
      },
    ))
        .stream;
  } else {
    var watcher = chokidar.watch(path, ChokidarOptions(usePolling: poll));
    watcher
      ..on(
          'add',
          (String path, [void _]) {
            controller?.add(WatchEvent(ChangeType.ADD, path));
          }.toJS)
      ..on(
          'change',
          (String path, [void _]) {
            controller?.add(WatchEvent(ChangeType.MODIFY, path));
          }.toJS)
      ..on(
          'unlink',
          (String path) {
            controller?.add(WatchEvent(ChangeType.REMOVE, path));
          }.toJS)
      ..on(
          'error',
          (JSError error) {
            controller?.addError(error);
          }.toJS);

    var completer = Completer<Stream<WatchEvent>>();
    watcher.on(
      'ready',
      () {
        // dart-lang/sdk#45348
        var stream = (controller = StreamController<WatchEvent>(
          onCancel: () {
            watcher.close();
          },
        ))
            .stream;
        completer.complete(stream);
      }.toJS,
    );

    return completer.future;
  }
}
