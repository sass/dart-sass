// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'importer/async.dart';
import 'importer/no_op.dart';
import 'importer/result.dart';

export 'importer/async.dart';
export 'importer/filesystem.dart';
export 'importer/package.dart';
export 'importer/result.dart';

/// An interface for importers that resolves URLs in `@import`s to the contents
/// of Sass files.
///
/// Importers should override [toString] to provide a human-readable description
/// of the importer. For example, the default filesystem importer returns its
/// load path.
///
/// This extends [AsyncImporter] to guarantee that [canonicalize] and [load] are
/// synchronous. It's usable with both the synchronous and asynchronous
/// `compile()` functions, and as such should be extended in preference to
/// [AsyncImporter] if possible.
///
/// Subclasses should extend [Importer], not implement it.
abstract class Importer extends AsyncImporter {
  /// An importer that never imports any stylesheets.
  ///
  /// This is used for stylesheets which don't support relative imports, such as
  /// those created from Dart code with plain strings.
  static final Importer noOp = new NoOpImporter();

  Uri canonicalize(Uri url);

  ImporterResult load(Uri url);

  DateTime modificationTime(Uri url) => new DateTime.now();
}
