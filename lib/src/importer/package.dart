// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:package_config/package_config_types.dart';

import '../importer.dart';

/// A filesystem importer to use when resolving the results of `package:` URLs.
///
/// This allows us to avoid duplicating the logic for choosing an extension and
/// looking for partials.
final _filesystemImporter = FilesystemImporter('.');

/// An importer that loads stylesheets from `package:` imports.
///
/// {@category Importer}
@sealed
class PackageImporter extends Importer {
  /// The resolver that converts `package:` imports to `file:`.
  final PackageConfig _packageConfig;

  /// Creates an importer that loads stylesheets from `package:` URLs according
  /// to [packageConfig], which is a [PackageConfig][] from the `package_config`
  /// package.
  ///
  /// [`PackageConfig`]: https://pub.dev/documentation/package_config/latest/package_config.package_config/PackageConfig-class.html
  PackageImporter(PackageConfig packageConfig) : _packageConfig = packageConfig;

  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') return _filesystemImporter.canonicalize(url);
    if (url.scheme != 'package') return null;

    var resolved = _packageConfig.resolve(url);
    if (resolved == null) throw "Unknown package.";

    if (resolved.scheme.isNotEmpty && resolved.scheme != 'file') {
      throw "Unsupported URL $resolved.";
    }

    return _filesystemImporter.canonicalize(resolved);
  }

  ImporterResult? load(Uri url) => _filesystemImporter.load(url);

  DateTime modificationTime(Uri url) =>
      _filesystemImporter.modificationTime(url);

  bool couldCanonicalize(Uri url, Uri canonicalUrl) =>
      (url.scheme == 'file' || url.scheme == 'package' || url.scheme == '') &&
      _filesystemImporter.couldCanonicalize(Uri(path: url.path), canonicalUrl);

  String toString() => "package:...";
}
