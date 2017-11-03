// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../importer.dart';
import '../io.dart';
import '../util/path.dart';
import 'result.dart';
import 'utils.dart';

/// An importer that loads files from a load path on the filesystem.
class FilesystemImporter extends Importer {
  /// The path relative to which this importer looks for files.
  final String _loadPath;

  /// Creates an importer that loads files relative to [loadPath].
  FilesystemImporter(this._loadPath);

  Uri canonicalize(Uri url) {
    var resolved = resolveImportPath(p.join(_loadPath, p.fromUri(url)));
    return resolved == null ? null : p.toUri(p.canonicalize(resolved));
  }

  ImporterResult load(Uri url) {
    var path = p.fromUri(url);
    return new ImporterResult(readFile(path),
        sourceMapUrl: url, indented: p.extension(path) == '.sass');
  }

  String toString() => _loadPath;
}
