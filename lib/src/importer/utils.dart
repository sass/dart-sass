// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import '../io.dart';

/// Resolves an imported path using the same logic as the filesystem importer.
///
/// This tries to fill in extensions and partial prefixes and check if a directory default. If no file can be
/// found, it returns `null`.
String resolveImportPath(String path) {
  var extension = p.extension(path);
  if (extension == '.sass' || extension == '.scss' || extension == '.css') {
    return _exactlyOne(_tryPath(path));
  }

  return _exactlyOne(_tryPathWithExtensions(path)) ?? _tryPathAsDirectory(path);
}

/// Like [_tryPath], but checks both `.sass` and `.scss` extensions.
List<String> _tryPathWithExtensions(String path) {
  var result = _tryPath(path + '.sass')..addAll(_tryPath(path + '.scss'));
  return result.isNotEmpty ? result : _tryPath(path + '.css');
}

/// Returns the [path] and/or the partial with the same name, if either or both
/// exists.
///
/// If neither exists, returns an empty list.
List<String> _tryPath(String path) {
  var paths = <String>[];
  var partial = p.join(p.dirname(path), "_${p.basename(path)}");
  if (fileExists(partial)) paths.add(partial);
  if (fileExists(path)) paths.add(path);
  return paths;
}

/// Returns the resolved index file for [path] if [path] is a directory and the
/// index file exists.
///
/// Otherwise, returns `null`.
String _tryPathAsDirectory(String path) => dirExists(path)
    ? _exactlyOne(_tryPathWithExtensions(p.join(path, 'index')))
    : null;

/// If [paths] contains exactly one path, returns that path.
///
/// If it contains no paths, returns `null`. If it contains more than one,
/// throws an exception.
String _exactlyOne(List<String> paths) {
  if (paths.isEmpty) return null;
  if (paths.length == 1) return paths.first;

  throw "It's not clear which file to import. Found:\n" +
      paths.map((path) => "  " + p.prettyUri(p.toUri(path))).join("\n");
}
