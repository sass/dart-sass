// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../importer.dart';

/// An importer that never imports any stylesheets.
///
/// This is used for stylesheets which don't support relative imports, such as
/// those created from Dart code with plain strings.
final class NoOpImporter extends Importer {
  @override
  Uri? canonicalize(Uri url) => null;

  @override
  ImporterResult? load(Uri url) => null;

  @override
  bool couldCanonicalize(Uri url, Uri canonicalUrl) => false;

  @override
  String toString() => "(unknown)";
}
