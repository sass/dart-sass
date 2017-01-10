// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// A class that defines how to resolve `package:` URIs.
///
/// This includes the information necessary to resolve `package:` URIs using
/// either a package config or a package root. It can be used both as a standard
/// cross-package representation of the user's configuration, and as a means of
/// concretely locating packages and the assets they contain.
///
/// Unlike [PackageResolver], all members on this are synchronous, which may
/// require that more data be loaded up front. This is useful when primarily
/// dealing with user-created package resolution strategies, whereas
/// [PackageInfo] is usually preferable when the current Isolate's package
/// resolution logic may be used.
///
/// This class should not be implemented by user code.
abstract class SyncPackageResolver {
  /// The map contained in the parsed package config.
  ///
  /// This maps package names to the base URIs for those packages. These are
  /// already resolved relative to [packageConfigUri], so if they're relative
  /// they should be considered relative to [Uri.base]. They're normalized to
  /// ensure that all URLs end with a trailing slash.
  ///
  /// [urlFor] should generally be used rather than looking up package URLs in
  /// this map, to ensure that code works with a package root as well as a
  /// package config.
  ///
  /// Returns `null` when using a [packageRoot] for resolution, or when no
  /// package resolution is being used.
  Map<String, Uri> get packageConfigMap;

  /// The URI for the package config.
  ///
  /// This is the URI from which [packageConfigMap] was parsed, if that's
  /// available. Otherwise, it's a `data:` URI containing a serialized
  /// representation of [packageConfigMap]. This `data:` URI should be accepted
  /// by all Dart tools.
  ///
  /// Note that if this is a `data:` URI, it's likely not safe to pass as a
  /// parameter to a Dart process due to length limits.
  ///
  /// Returns `null` when using a [packageRoot] for resolution, or when no
  /// package resolution is being used.
  Uri get packageConfigUri;

  /// The base URL for resolving `package:` URLs.
  ///
  /// This is normalized so that it always ends with a trailing slash.
  ///
  /// Returns `null` when using a [packageConfigMap] for resolution, or when no
  /// package resolution is being used.
  Uri get packageRoot;

  /// Returns the argument to pass to a subprocess to get it to use this package
  /// resolution strategy when resolving `package:` URIs.
  ///
  /// This uses the `--package-root` or `--package` flags, which are the
  /// convention supported by the Dart VM and dart2js.
  ///
  /// Note that if [packageConfigUri] is a `data:` URI, it may be too large to
  /// pass on the command line.
  ///
  /// Returns `null` if no package resolution is in use.
  String get processArgument;

  /// Returns a package resolution strategy describing how the current isolate
  /// resolves `package:` URIs.
  ///
  /// This may throw exceptions if loading or parsing the isolate's package map
  /// fails.
  static final Future<SyncPackageResolver> current = null;

  /// Resolves [packageUri] according to this package resolution strategy.
  ///
  /// [packageUri] may be a [String] or a [Uri]. This throws a [FormatException]
  /// if [packageUri] isn't a `package:` URI or doesn't have at least one path
  /// segment.
  ///
  /// If [packageUri] refers to a package that's not in the package spec, this
  /// returns `null`.
  Uri resolveUri(packageUri);

  /// Returns the resolved URL for [package] and [path].
  ///
  /// This is equivalent to `resolveUri("package:$package/")` or
  /// `resolveUri("package:$package/$path")`, depending on whether [path] was
  /// passed.
  ///
  /// If [package] refers to a package that's not in the package spec, this
  /// returns `null`.
  Uri urlFor(String package, [String path]);

  /// Returns the `package:` URI for [url].
  ///
  /// If [url] can't be referred to using a `package:` URI, returns `null`.
  ///
  /// [url] may be a [String] or a [Uri].
  Uri packageUriFor(url);

  /// Returns the path on the local filesystem to the root of [package], or
  /// `null` if the root cannot be found.
  ///
  /// **Note**: this assumes a pub-style package layout. In particular:
  ///
  /// * If a package root is being used, this assumes that it contains symlinks
  ///   to packages' lib/ directories.
  ///
  /// * If a package config is being used, this assumes that each entry points
  ///   to a package's lib/ directory.
  ///
  /// If these assumptions are broken, this may return `null` or it may return
  /// an invalid result.
  ///
  /// Returns `null` if the package root is not a `file:` URI, or if the package
  /// config entry for [package] is not a `file:` URI.
  String packagePath(String package);
}
