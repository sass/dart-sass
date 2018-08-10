// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import '../importer.dart';
import '../io.dart' as io;
import '../syntax.dart';
import 'result.dart';
import 'utils.dart';

/// An importer that loads files from a load path on the filesystem.
class FilesystemImporter extends Importer {
  /// The path relative to which this importer looks for files.
  final String _loadPath;

  /// Creates an importer that loads files relative to [loadPath].
  FilesystemImporter(this._loadPath);

  Uri canonicalize(Uri url) {
    if (url.scheme != 'file' && url.scheme != '') return null;
    var resolved = resolveImportPath(p.join(_loadPath, p.fromUri(url)));
    return resolved == null ? null : p.toUri(p.canonicalize(resolved));
  }

  ImporterResult load(Uri url) {
    var path = p.fromUri(url);
    return new ImporterResult(io.readFile(path),
        sourceMapUrl: url, syntax: Syntax.forPath(path));
  }

  DateTime modificationTime(Uri url) => io.modificationTime(p.fromUri(url));

  String toString() => _loadPath;
}
