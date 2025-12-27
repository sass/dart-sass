// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// An enum of sourceMapIncludeSources options.
///
/// {@category Compile}
enum SourceMapIncludeSources {
  /// Let compiler decide whether to include each source content.
  auto,

  /// Always include source contents.
  always,

  /// Never include source contents.
  never,
}
