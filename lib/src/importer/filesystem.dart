// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../deprecation.dart';
import '../evaluation_context.dart';
import '../importer.dart';
import '../io.dart' as io;
import '../syntax.dart';
import '../util/nullable.dart';
import 'utils.dart';

/// An importer that loads files from a load path on the filesystem, either
/// relative to the path passed to [FilesystemImporter.new] or absolute `file:`
/// URLs.
///
/// Use [FilesystemImporter.noLoadPath] to _only_ load absolute `file:` URLs and
/// URLs relative to the current file.
///
/// {@category Importer}
@sealed
class FilesystemImporter extends Importer {
  /// The path relative to which this importer looks for files.
  ///
  /// If this is `null`, this importer will _only_ load absolute `file:` URLs
  /// and URLs relative to the current file.
  final String? _loadPath;

  /// Whether loading from files from this importer's [_loadPath] is deprecated.
  final bool _loadPathDeprecated;

  /// Creates an importer that loads files relative to [loadPath].
  FilesystemImporter(String loadPath)
      : _loadPath = p.absolute(loadPath),
        _loadPathDeprecated = false;

  FilesystemImporter._deprecated(String loadPath)
      : _loadPath = p.absolute(loadPath),
        _loadPathDeprecated = true;

  /// Creates an importer that _only_ loads absolute `file:` URLs and URLs
  /// relative to the current file.
  FilesystemImporter._noLoadPath()
      : _loadPath = null,
        _loadPathDeprecated = false;

  /// A [FilesystemImporter] that loads files relative to the current working
  /// directory.
  ///
  /// Historically, this was the best default for supporting `file:` URL loads
  /// when the load path didn't matter. However, adding the current working
  /// directory to the load path wasn't always desirable, so it's no longer
  /// recommneded. Instead, either use [FilesystemImporter.noLoadPath] if the
  /// load path doesn't matter, or `FilesystemImporter('.')` to explicitly
  /// preserve the existing behavior.
  @Deprecated(
      "Use FilesystemImporter.noLoadPath or FilesystemImporter('.') instead.")
  static final cwd = FilesystemImporter._deprecated('.');

  /// Creates an importer that _only_ loads absolute `file:` URLsand URLs
  /// relative to the current file.
  static final noLoadPath = FilesystemImporter._noLoadPath();

  Uri? canonicalize(Uri url) {
    String? resolved;
    if (url.scheme == 'file') {
      resolved = resolveImportPath(p.fromUri(url));
    } else if (url.scheme != '') {
      return null;
    } else if (_loadPath case var loadPath?) {
      resolved = resolveImportPath(p.join(loadPath, p.fromUri(url)));

      if (resolved != null && _loadPathDeprecated) {
        warnForDeprecation(
            "Using the current working directory as an implicit load path is "
            "deprecated. Either add it as an explicit load path or importer, or "
            "load this stylesheet from a different URL.",
            Deprecation.fsImporterCwd);
      }
    } else {
      return null;
    }

    return resolved.andThen((resolved) => p.toUri(io.canonicalize(resolved)));
  }

  ImporterResult? load(Uri url) {
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

  String toString() => _loadPath ?? '<absolute file importer>';
}
