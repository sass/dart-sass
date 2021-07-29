// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:watcher/watcher.dart';

/// An output sink that writes to this process's standard error.
class Stderr {
  /// Writes the string representation of [object] to standard error.
  void write(Object object) {}

  /// Writes the string representation of [object] to standard error, followed
  /// by a newline.
  ///
  /// If [object] is `null`, just writes a newline.
  void writeln([Object? object]) {}

  /// Flushes any buffered text.
  void flush() {}
}

/// An error thrown by [readFile].
class FileSystemException {
  String get message => throw '';
  String? get path => throw '';
}

/// The standard error for the current process.
Stderr get stderr => throw '';

/// Whether the current process is running on Windows.
bool get isWindows => throw '';

/// Whether the current process is running on Mac OS.
bool get isMacOS => throw '';

/// Returns whether or not stdout is connected to an interactive terminal.
bool get hasTerminal => throw '';

/// Whether we're running as Node.JS.
bool get isNode => throw '';

/// Whether this process is connected to a terminal that supports ANSI escape
/// sequences.
bool get supportsAnsiEscapes => throw '';

/// The current working directory.
String get currentPath => throw '';

/// Reads the file at [path] as a UTF-8 encoded string.
///
/// Throws a [FileSystemException] if reading fails, and a [SassException] if
/// the file isn't valid UTF-8.
String readFile(String path) => throw '';

/// Writes [contents] to the file at [path], encoded as UTF-8.
///
/// Throws a [FileSystemException] if writing fails.
void writeFile(String path, String contents) => throw '';

/// Deletes the file at [path].
///
/// Throws a [FileSystemException] if deletion fails.
void deleteFile(String path) => throw '';

/// Reads from the standard input for the current process until it closes,
/// returning the contents.
Future<String> readStdin() async => throw '';

/// Returns whether a file at [path] exists.
bool fileExists(String path) => throw '';

/// Returns whether a dir at [path] exists.
bool dirExists(String path) => throw '';

/// Ensures that a directory exists at [path], creating it and its ancestors if
/// necessary.
void ensureDir(String path) => throw '';

/// Lists the files (not sub-directories) in the directory at [path].
///
/// If [recursive] is `true`, this lists files in directories transitively
/// beneath [path] as well.
Iterable<String> listDir(String path, {bool recursive = false}) => throw '';

/// Returns the modification time of the file at [path].
DateTime modificationTime(String path) => throw '';

/// Returns the value of the environment variable with the given [name], or
/// `null` if it's not set.
String? getEnvironmentVariable(String name) => throw '';

/// Gets and sets the exit code that the process will use when it exits.
int get exitCode => throw '';
set exitCode(int value) => throw '';

/// Attaches a listener to exit when stdin closes.
///
/// The listener is *not* attached when stdin is a TTY because it would
/// interfere with the Unix background job system. If we read from stdin and
/// then Ctrl+Z to move the process to the background, it will incorrectly
/// cause the job to stop. See: https://github.com/brunch/brunch/issues/998.
void ensureWatchWillExit() => throw '';

/// Recursively watches the directory at [path] for modifications.
///
/// Returns a future that completes with a single-subscription stream once the
/// directory has been scanned initially. The watch is canceled when the stream
/// is closed.
///
/// If [poll] is `true`, this manually checks the filesystem for changes
/// periodically rather than using a native filesystem monitoring API.
Future<Stream<WatchEvent>> watchDir(String path, {bool poll = false}) =>
    throw '';
