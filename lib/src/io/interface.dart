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

/// The standard error for the current process.
Stderr get stderr => null;

/// Returns the arguments for the current process.
///
/// If the arguments are available globally, the global value is returned.
/// Otherwise, [mainArguments] (which should be the arguments passed to
/// `main()`) is returned.
List<String> getArguments(List<String> mainArguments) => null;

/// Reads the file at [path].
String readFile(String path) => null;

/// Returns whether a file at [path] exists.
bool fileExists(String path) => null;

/// Exits the process with the given [exitCode].
void exit(int exitCode) {}
