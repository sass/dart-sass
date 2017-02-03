// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

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

/// An error thrown by [readFileAsBytes] and [readFileAsString].
class FileSystemException {
  String get message => null;
}

/// The standard error for the current process.
Stderr get stderr => null;

/// Returns whether or not stdout is connected to an interactive terminal.
bool get hasTerminal => false;

/// Reads the file at [path] as a list of bytes.
List<int> readFileAsBytes(String path) => null;

/// Reads the file at [path] as a UTF-8 encoded string.
String readFileAsString(String path) => null;

/// Returns whether a file at [path] exists.
bool fileExists(String path) => null;

/// Returns whether a dir at [path] exists.
bool dirExists(String path) => null;

/// Gets and sets the exit code that the process will use when it exits.
int exitCode;
