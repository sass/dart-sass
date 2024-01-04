// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:sass/src/util/map.dart';
import 'package:sass/src/util/nullable.dart';

import '../importer.dart';
import './utils.dart';
import 'dart:convert';
import '../io.dart';
import 'package:path/path.dart' as p;

/// An [Importer] that resolves `pkg:` URLs using the Node resolution algorithm.
class NodePackageImporter extends Importer {
  /// The starting path for canonicalizations without a containing URL.
  final String _entryPointPath;

  /// Creates a Node Package Importer with the associated entry point.
  NodePackageImporter(this._entryPointPath);

  static const validExtensions = {'.scss', '.sass', '.css'};

  @override
  bool isNonCanonicalScheme(String scheme) => scheme == 'pkg';

  @override
  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') return FilesystemImporter.cwd.canonicalize(url);
    if (url.scheme != 'pkg') return null;

    if (url.hasAuthority) {
      throw "pkg: URL $url must not have a host, port, username or password.";
    }
    if (p.isAbsolute(url.path)) {
      throw "pkg: URL $url must not be an absolute path.";
    }
    if (url.path.isEmpty) {
      throw "pkg: URL $url must not have an empty path.";
    }
    if (url.hasQuery || url.hasFragment) {
      throw "pkg: URL $url must not have a query or fragment.";
    }

    var basePath = containingUrl?.scheme == 'file'
        ? p.fromUri(containingUrl!)
        : _entryPointPath;

    var (packageName, subpath) = _packageNameAndSubpath(url.path);
    var packageRoot = _resolvePackageRoot(packageName, basePath);

    if (packageRoot == null) return null;
    var jsonPath = p.join(packageRoot, 'package.json');

    var jsonString = readFile(jsonPath);
    Map<String, dynamic> packageManifest;
    try {
      packageManifest = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw "'package.json' in 'pkg:$packageName' cannot be parsed.";
    }

    if (_resolvePackageExports(
            packageRoot, subpath, packageManifest, packageName)
        case var resolved?) {
      if (validExtensions.contains(p.extension(resolved))) {
        return p.toUri(resolved);
      } else {
        throw "The export for '${subpath ?? "root"}' in "
            "'$packageName' resolved to '${resolved.toString()}', "
            "which is not a '.scss', '.sass', or '.css' file.";
      }
    }
    // If no subpath, attempt to resolve `sass` or `style` key in package.json,
    // then `index` file at package root, resolved for file extensions and
    // partials.
    if (subpath == null) {
      var rootPath = _resolvePackageRootValues(packageRoot, packageManifest);
      return rootPath != null ? p.toUri(rootPath) : null;
    }

    // If there is a subpath, attempt to resolve the path relative to the
    // package root, and resolve for file extensions and partials.
    var relativeSubpath = p.join(packageRoot, subpath);
    return FilesystemImporter.cwd.canonicalize(p.toUri(relativeSubpath));
  }

  @override
  ImporterResult? load(Uri url) => FilesystemImporter.cwd.load(url);

  /// Splits a [bare import
  /// specifier](https://nodejs.org/api/esm.html#import-specifiers) `specifier`
  /// into its package name and subpath, if one exists.
  ///
  /// Because this is a bare import specifier and not a path, we always use `/`
  /// to avoid invalid values on non-Posix machines.
  (String, String?) _packageNameAndSubpath(String specifier) {
    var parts = p.posix.split(specifier);
    var name = parts.removeAt(0);

    if (name.startsWith('.')) {
      throw "pkg: name $name must not start with a '.'.";
    }
    if (name.contains('\\')) {
      throw "pkg: name $name must not contain a '\\'.";
    }
    if (name.contains('%')) {
      throw "pkg: name $name must not contain a '%'.";
    }

    if (name.startsWith('@')) {
      if (parts.isEmpty) {
        throw "pkg: name $name is an invalid package name."
            "Scoped packages, which start with '@', must have a second segment.";
      }
      name = p.posix.join(name, parts.removeAt(0));
    }

    return (name, parts.isNotEmpty ? p.posix.joinAll(parts) : null);
  }

  /// Returns an absolute path to the root directory for the most proximate
  /// installed `packageName`.
  ///
  /// Implementation of `PACKAGE_RESOLVE` from the [Resolution Algorithm
  /// Specification](https://nodejs.org/api/esm.html#resolution-algorithm-specification).
  String? _resolvePackageRoot(String packageName, String basePath) {
    var baseDirectory = p.dirname(basePath);

    String? recurseUpFrom(String entry) {
      var potentialPackage = p.join(entry, 'node_modules', packageName);

      if (dirExists(potentialPackage)) return potentialPackage;
      var parent = p.dirname(entry);

      // prevent infinite recursion
      if (entry == parent) return null;

      var rootLength = isWindows ? 1 : 0;

      if (Uri.directory(parent).pathSegments.length == rootLength) return null;

      return recurseUpFrom(parent);
    }

    return recurseUpFrom(baseDirectory);
  }

  /// Returns a file path specified by the `sass` or `style` values in a package
  /// manifest, or an `index` file relative to the package root.
  String? _resolvePackageRootValues(
      String packageRoot, Map<String, dynamic> packageManifest) {
    if (packageManifest['sass'] case String sassValue) {
      if (validExtensions.contains(p.extension(sassValue))) {
        return p.url.join(packageRoot, sassValue);
      }
    }

    if (packageManifest['style'] case String styleValue) {
      if (validExtensions.contains(p.extension(styleValue))) {
        return p.url.join(packageRoot, styleValue);
      }
    }

    var result = resolveImportPath(p.url.join(packageRoot, 'index'));
    if (result != null) return result;
    return null;
  }

  /// Returns a file path specified by a `subpath` in the `exports` section of
  /// package.json.
  ///
  /// `packageName` is used for error reporting.
  String? _resolvePackageExports(String packageRoot, String? subpath,
      Map<String, dynamic> packageManifest, String packageName) {
    if (packageManifest['exports'] == null) return null;
    var exports = packageManifest['exports'] as Object;
    var subpathVariants = _exportsToCheck(subpath);
    if (_nodePackageExportsResolve(
            packageRoot, subpathVariants, exports, subpath, packageName)
        case String path) {
      return path;
    }

    if (subpath != null && p.extension(subpath).isNotEmpty) return null;

    var subpathIndexVariants = _exportsToCheck(subpath, addIndex: true);
    if (_nodePackageExportsResolve(
            packageRoot, subpathIndexVariants, exports, subpath, packageName)
        case String path) {
      return path;
    }

    return null;
  }

  /// Returns the path to one subpath variants, resolved in the `exports` of a
  /// package manifest.
  ///
  /// Throws an error if multiple `subpathVariants` match, and null if none
  /// match.
  ///
  /// Implementation of `PACKAGE_EXPORTS_RESOLVE` from the [Resolution Algorithm
  /// Specification](https://nodejs.org/api/esm.html#resolution-algorithm-specification).
  String? _nodePackageExportsResolve(
      String packageRoot,
      List<String?> subpathVariants,
      Object exports,
      String? subpath,
      String packageName) {
    if (exports is Map<String, dynamic>) {
      if (exports.keys.any((key) => key.startsWith('.')) &&
          exports.keys.any((key) => !key.startsWith('.'))) {
        throw 'Invalid Package Configuration';
      }
    }
    String? processVariant(String? subpath) {
      if (subpath == null) {
        return _getMainExport(exports).andThen((mainExport) =>
            _packageTargetResolve(subpath, mainExport, packageRoot));
      }
      if (exports is! Map<String, dynamic> ||
          exports.keys.every((key) => !key.startsWith('.'))) {
        return null;
      }
      var matchKey = "./$subpath";
      if (exports.containsKey(matchKey) && !matchKey.contains('*')) {
        return _packageTargetResolve(
            matchKey, exports[matchKey] as Object, packageRoot);
      }

      var expansionKeys = [
        for (var key in exports.keys)
          if (key.split('').where((char) => char == '*').length == 1) key
      ]..sort(_compareExpansionKeys);

      for (var expansionKey in expansionKeys) {
        var [patternBase, patternTrailer] = expansionKey.split('*');
        if (!matchKey.startsWith(patternBase)) continue;
        if (matchKey == patternBase) continue;
        if (patternTrailer.isEmpty ||
            (matchKey.endsWith(patternTrailer) &&
                matchKey.length >= expansionKey.length)) {
          var target = exports[expansionKey] as Object;
          var patternMatch = matchKey.substring(
              patternBase.length, matchKey.length - patternTrailer.length);
          return _packageTargetResolve(
              subpath, target, packageRoot, patternMatch);
        }
      }

      return null;
    }

    var matches = subpathVariants.map(processVariant).whereNotNull().toList();

    switch (matches) {
      case [var path]:
        return path;
      case [_, _, ...] && var paths:
        throw "Unable to determine which of multiple potential resolutions "
            "found for ${subpath ?? 'root'} in $packageName should be used. "
            "\n\nFound:\n"
            "${paths.join('\n')}";
    }
    return null;
  }

  /// Implementation of the `PATTERN_KEY_COMPARE` comparator from
  /// https://nodejs.org/api/esm.html#resolution-algorithm-specification.
  int _compareExpansionKeys(String keyA, String keyB) {
    var baseLengthA = keyA.contains('*') ? keyA.indexOf('*') + 1 : keyA.length;
    var baseLengthB = keyB.contains('*') ? keyB.indexOf('*') + 1 : keyB.length;
    if (baseLengthA > baseLengthB) return -1;
    if (baseLengthB > baseLengthA) return 1;
    if (!keyA.contains("*")) return 1;
    if (!keyB.contains("*")) return -1;
    if (keyA.length > keyB.length) return -1;
    if (keyB.length > keyA.length) return 1;
    return 0;
  }

  /// Returns a file path to `subpath`, resolved in the `exports` object.
  ///
  /// Verifies the file exists relative to `packageRoot`. Instances of `*`
  /// will be replaced with `patternMatch`.
  ///
  /// Implementation of `PACKAGE_TARGET_RESOLVE` from the [Resolution Algorithm
  /// Specification](https://nodejs.org/api/esm.html#resolution-algorithm-specification).
  String? _packageTargetResolve(
      String? subpath, Object exports, String packageRoot,
      [String? patternMatch]) {
    switch (exports) {
      case String string:
        if (!string.startsWith('./')) {
          throw "Export '$string' must be a path relative to the package root at '$packageRoot'.";
        }
        if (patternMatch != null) {
          var replaced = string.replaceAll(RegExp(r'\*'), patternMatch);
          var path = p.normalize(p.join(packageRoot, replaced));
          return fileExists(path) ? path : null;
        }
        return p.join(packageRoot, string);
      case Map<String, dynamic> map:
        var conditions = ['sass', 'style', 'default'];
        for (var (key, value) in map.pairs) {
          if (!conditions.contains(key)) continue;
          if (_packageTargetResolve(
                  subpath, value as Object, packageRoot, patternMatch)
              case var result?) {
            return result;
          }
        }
        return null;

      case []:
        return null;

      case List<dynamic> array:
        for (var value in array) {
          var result = _packageTargetResolve(
              subpath, value as Object, packageRoot, patternMatch);
          if (result != null) {
            return result;
          }
        }

        return null;

      default:
        throw "Invalid 'exports' value in ${p.join(packageRoot, 'package.json')}";
    }
  }

  /// Returns a path to a package's export without a subpath.
  Object? _getMainExport(Object exports) {
    Object? parseMap(Map<String, dynamic> map) {
      if (!map.keys.any((key) => key.startsWith('.'))) {
        return map;
      }
      if (map.containsKey('.')) {
        return map['.'] as Object;
      }
      return null;
    }

    return switch (exports) {
      String string => string,
      List<String> list => list,
      Map<String, dynamic> map => parseMap(map),
      _ => null
    };
  }

  /// Returns a list of all possible variations of `subpath` with extensions and
  /// partials.
  ///
  /// `subpath` is part of the [bare import specifier], so we use the `/`
  /// separator.
  List<String?> _exportsToCheck(String? subpath, {bool addIndex = false}) {
    var paths = <String>[];

    if (subpath == null && addIndex) {
      subpath = 'index';
    } else if (subpath != null && addIndex) {
      subpath = p.posix.join(subpath, 'index');
    }
    if (subpath == null) return [null];

    if (['scss', 'sass', 'css'].any((ext) => subpath!.endsWith(ext))) {
      paths.add(subpath);
    } else {
      paths.addAll([
        '$subpath.scss',
        '$subpath.sass',
        '$subpath.css',
      ]);
    }
    var subpathSegments = p.posix.split(subpath);
    var basename = subpathSegments.last;
    if (!basename.startsWith('_')) {
      List<String> prefixedPaths = [];
      for (final path in paths) {
        var dirPath = subpathSegments.sublist(0, subpathSegments.length - 1);
        var pathBasename = p.posix.split(path).last;
        if (dirPath.isEmpty) {
          prefixedPaths.add('_$pathBasename');
        } else {
          dirPath.add('_$pathBasename');
          prefixedPaths.add(p.posix.joinAll(dirPath));
        }
      }
      paths.addAll(prefixedPaths);
    }
    return paths;
  }
}
