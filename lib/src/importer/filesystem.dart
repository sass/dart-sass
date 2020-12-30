// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../importer.dart';
import '../io.dart' as io;
import '../syntax.dart';
import 'utils.dart';

/// An importer that loads files from a load path on the filesystem.
@sealed
class FilesystemImporter extends Importer {
  /// The path relative to which this importer looks for files.
  final String _loadPath;

  /// Creates an importer that loads files relative to [loadPath].
  FilesystemImporter(String loadPath) : _loadPath = p.absolute(loadPath);

  Uri canonicalize(Uri url) {
    if (url.scheme != 'file' && url.scheme != '') return null;
    var resolved = resolveImportPath(p.join(_loadPath, p.fromUri(url)));
    return resolved == null ? null : p.toUri(io.canonicalize(resolved));
  }

  ImporterResult load(Uri url) {
    var path = p.fromUri(url);
    return ImporterResult(io.readFile(path),
        sourceMapUrl: url, syntax: Syntax.forPath(path));
  }

  DateTime modificationTime(Uri url) => io.modificationTime(p.fromUri(url));

  bool couldCanonicalize(Uri url, Uri canonicalUrl) {
    if (url.scheme != 'file' && url.scheme != '') return false;
    if (canonicalUrl.scheme != 'file') return false;

    var basename = p.url.basename(url.path);
    var canonicalBasename = p.url.basename(canonicalUrl.path);
    if (!basename.startsWith("_") && canonicalBasename.startsWith("_")) {
      canonicalBasename = canonicalBasename.substring(1);
    }

    return basename == canonicalBasename ||
        basename == p.url.withoutExtension(canonicalBasename);
  }

  String toString() => _loadPath;
}
