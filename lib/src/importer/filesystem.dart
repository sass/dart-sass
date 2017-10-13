// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import '../importer.dart';
import '../io.dart';
import 'result.dart';

/// An importer that loads files from a load path on the filesystem.
class FilesystemImporter extends Importer {
  /// The path relative to which this importer looks for files.
  final String _loadPath;

  /// Creates an importer that loads files relative to [loadPath].
  FilesystemImporter(this._loadPath);

  Uri canonicalize(Uri url) {
    var urlPath = p.fromUri(url);
    var path = p.join(_loadPath, urlPath);
    print("canonicalize: $url, $_loadPath, $urlPath, $path");
    var extension = p.extension(path);
    var resolved = extension == '.sass' || extension == '.scss'
        ? _tryPath(path)
        : _tryPathWithExtensions(path);
    return resolved == null ? null : p.toUri(p.canonicalize(resolved));
  }

  /// Like [_tryPath], but checks both `.sass` and `.scss` extensions.
  String _tryPathWithExtensions(String path) =>
      _tryPath(path + '.sass') ?? _tryPath(path + '.scss');

  /// If a file exists at [path], or a partial with the same name exists,
  /// returns the resolved path.
  ///
  /// Otherwise, returns `null`.
  String _tryPath(String path) {
    var partial = p.join(p.dirname(path), "_${p.basename(path)}");
    if (fileExists(partial)) return partial;
    if (fileExists(path)) return path;
    return null;
  }

  ImporterResult load(Uri url) {
    print("load $url");
    var path = p.fromUri(url);
    print("path: $path");
    print("style: ${p.context.style}");
    return null;
    return new ImporterResult(readFile(path),
        sourceMapUrl: url, indented: p.extension(path) == '.sass');
  }

  String toString() => _loadPath;
}
