// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:watcher/watcher.dart';

import '../exception.dart';

export 'dart:io' show exitCode, FileSystemException;

io.Stdout get stderr => io.stderr;

bool get isWindows => io.Platform.isWindows;

bool get isMacOS => io.Platform.isMacOS;

bool get hasTerminal => io.stdout.hasTerminal;

bool get isNode => false;

bool get supportsAnsiEscapes {
  if (!hasTerminal) return false;

  // We don't trust [io.stdout.supportsAnsiEscapes] except on Windows because it
  // relies on the TERM environment variable which has many false negatives.
  if (!isWindows) return true;
  return io.stdout.supportsAnsiEscapes;
}

String get currentPath => io.Directory.current.path;

String readFile(String path) {
  var bytes = io.File(path).readAsBytesSync();

  try {
    return utf8.decode(bytes);
  } on FormatException catch (error) {
    var decodedUntilError =
        utf8.decode(bytes.sublist(0, error.offset), allowMalformed: true);
    var stringOffset = decodedUntilError.length;
    if (decodedUntilError.endsWith("�")) stringOffset--;

    var decoded = utf8.decode(bytes, allowMalformed: true);
    var sourceFile = SourceFile.fromString(decoded, url: p.toUri(path));
    throw SassException(
        "Invalid UTF-8.", sourceFile.location(stringOffset).pointSpan());
  }
}

void writeFile(String path, String contents) =>
    io.File(path).writeAsStringSync(contents);

void deleteFile(String path) => io.File(path).deleteSync();

Future<String> readStdin() async {
  var completer = Completer<String>();
  completer.complete(await io.systemEncoding.decodeStream(io.stdin));
  return completer.future;
}

bool fileExists(String path) => io.File(path).existsSync();

bool dirExists(String path) => io.Directory(path).existsSync();

void ensureDir(String path) => io.Directory(path).createSync(recursive: true);

Iterable<String> listDir(String path, {bool recursive = false}) =>
    io.Directory(path)
        .listSync(recursive: recursive)
        .whereType<io.File>()
        .map((entity) => entity.path);

DateTime modificationTime(String path) {
  var stat = io.FileStat.statSync(path);
  if (stat.type == io.FileSystemEntityType.notFound) {
    throw io.FileSystemException("File not found.", path);
  }
  return stat.modified;
}

String getEnvironmentVariable(String name) => io.Platform.environment[name];

Future<Stream<WatchEvent>> watchDir(String path, {bool poll = false}) async {
  var watcher = poll ? PollingDirectoryWatcher(path) : DirectoryWatcher(path);

  // Wrap [stream] in a [SubscriptionStream] so that its `onListen` event
  // triggers but the caller can still listen at their leisure.
  var stream = SubscriptionStream<WatchEvent>(watcher.events
      .transform(const SingleSubscriptionTransformer<WatchEvent, WatchEvent>())
      .listen(null));
  await watcher.ready;

  return stream;
}
