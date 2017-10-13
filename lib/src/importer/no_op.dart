// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../importer.dart';
import 'result.dart';

/// An importer that never imports any stylesheets.
///
/// This is used for stylesheets which don't support relative imports, such as
/// those created from Dart code with plain strings.
class NoOpImporter extends Importer {
  Uri canonicalize(Uri url) => null;
  ImporterResult load(Uri url) => null;

  String toString() => "(unknown)";
}
