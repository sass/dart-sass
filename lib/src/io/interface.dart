// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

/// An output sink that writes to this process's standard error.
class Stderr {
  /// Writes the string representation of [object] to standard error.
  void write(object) {}

  /// Writes the string representation of [object] to standard error, followed
  /// by a newline.
  ///
  /// If [object] is `null`, just writes a newline.
  void writeln([object]) {}

  /// Flushes any buffered text.
  void flush() {}
}

/// An error thrown by [readFile].
class FileSystemException {
  String get message => null;
  String get path => null;
}

/// The standard error for the current process.
Stderr get stderr => null;

/// Whether the current process is running on Windows.
bool get isWindows => false;

/// Returns whether or not stdout is connected to an interactive terminal.
bool get hasTerminal => false;

/// Whether we're running as Node.JS.
bool get isNode => false;

/// The current working directory.
String get currentPath => null;

/// Reads the file at [path] as a UTF-8 encoded string.
///
/// Throws a [FileSystemException] if reading fails, and a [SassException] if
/// the file isn't valid UTF-8.
String readFile(String path) => null;

/// Writes [contents] to the file at [path], encoded as UTF-8.
///
/// Throws a [FileSystemException] if writing fails.
void writeFile(String path, String contents) => null;

/// Reads from the standard input for the current process until it closes,
/// returning the contents.
Future<String> readStdin() async => null;

/// Returns whether a file at [path] exists.
bool fileExists(String path) => null;

/// Returns whether a dir at [path] exists.
bool dirExists(String path) => null;

/// Ensures that a directory exists at [path], creating it and its ancestors if
/// necessary.
void ensureDir(String path) => null;

/// Gets and sets the exit code that the process will use when it exits.
int exitCode;
