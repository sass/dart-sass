// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../importer.dart';
import '../sync_package_resolver.dart';
import 'filesystem.dart';
import 'result.dart';

/// A filesystem importer to use when resolving the results of `package:` URLs.
///
/// This allows us to avoid duplicating the logic for choosing an extension and
/// looking for partials.
final _filesystemImporter = new FilesystemImporter('.');

/// An importer that loads stylesheets from `package:` imports.
class PackageImporter extends Importer {
  /// The resolver that converts `package:` imports to `file:`.
  final SyncPackageResolver _packageResolver;

  /// Creates an importer that loads stylesheets from `package:` URLs according
  /// to [packageResolver], which is a [SyncPackageResolver][] from the
  /// `package_resolver` package.
  ///
  /// [SyncPackageResolver]: https://www.dartdocs.org/documentation/package_resolver/latest/package_resolver/SyncPackageResolver-class.html
  PackageImporter(this._packageResolver);

  Uri canonicalize(Uri url) {
    if (url.scheme != 'package') return null;

    var resolved = _packageResolver.resolveUri(url);
    if (resolved == null) throw "Unknown package.";

    if (resolved.scheme.isNotEmpty && resolved.scheme != 'file') {
      throw "Unsupported URL ${resolved}.";
    }

    return _filesystemImporter.canonicalize(resolved);
  }

  ImporterResult load(Uri url) => _filesystemImporter.load(url);

  DateTime modificationTime(Uri url) =>
      _filesystemImporter.modificationTime(url);

  String toString() => "package:...";
}
