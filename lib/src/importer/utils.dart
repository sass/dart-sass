// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../io.dart';
import '../util/path.dart';

/// Resolves an imported path using the same logic as the filesystem importer.
///
/// This tries to fill in extensions and partial prefixes and check if a directory default. If no file can be
/// found, it returns `null`.
String resolveImportPath(String path) {
  var extension = p.extension(path);
  var file = extension == '.sass' || extension == '.scss'
      ? _tryPath(path)
      : _tryPathWithExtensions(path);
  return file != null ? file : _tryPathAsDirectory(path);
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

/// Checks if path given is a directory then searches for a index file using [_tryPathWithExtensions]
/// returns the resolved path.
///
/// Otherwise, returns `null`.
String _tryPathAsDirectory(String path) {
  return dirExists(path) ? _tryPathWithExtensions(p.join(path, 'index')) : null;
}
