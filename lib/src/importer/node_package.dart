// Copyright 2024 Google Inc. Use of this source code is governed by an
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

  /// Creates a Node package importer with the associated entry point.
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
    } else if (p.isAbsolute(url.path)) {
      throw "pkg: URL $url must not be an absolute path.";
    } else if (url.path.isEmpty) {
      throw "pkg: URL $url must not have an empty path.";
    } else if (url.hasQuery || url.hasFragment) {
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
      throw "Failed to parse $jsonPath for \"pkg:$packageName\": $e";
    }

    if (_resolvePackageExports(
            packageRoot, subpath, packageManifest, packageName)
        case var resolved?) {
      if (validExtensions.contains(p.extension(resolved))) {
        return p.toUri(p.canonicalize(resolved));
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
      return rootPath != null ? p.toUri(p.canonicalize(rootPath)) : null;
    }

    // If there is a subpath, attempt to resolve the path relative to the
    // package root, and resolve for file extensions and partials.
    var subpathInRoot = p.join(packageRoot, subpath);
    return FilesystemImporter.cwd.canonicalize(p.toUri(subpathInRoot));
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
    var parts = p.url.split(specifier);
    var name = parts.removeAt(0);

    if (name.startsWith('.')) {
      throw "pkg: name $name must not start with a '.'.";
    } else if (name.contains('\\')) {
      throw "pkg: name $name must not contain a '\\'.";
    } else if (name.contains('%')) {
      throw "pkg: name $name must not contain a '%'.";
    }

    if (name.startsWith('@')) {
      if (parts.isEmpty) {
        throw "pkg: name $name is an invalid package name."
            "Scoped packages, which start with '@', must have a second segment.";
      }
      name = p.url.join(name, parts.removeAt(0));
    }
    var subpath = parts.isNotEmpty ? p.fromUri(p.url.joinAll(parts)) : null;
    return (name, subpath);
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
        return p.join(packageRoot, sassValue);
      }
    }

    if (packageManifest['style'] case String styleValue) {
      if (validExtensions.contains(p.extension(styleValue))) {
        return p.join(packageRoot, styleValue);
      }
    }

    var result = resolveImportPath(p.join(packageRoot, 'index'));
    if (result != null) return result;
    return null;
  }

  /// Returns a file path specified by a `subpath` in the `exports` section of
  /// package.json.
  ///
  /// `packageName` is used for error reporting.
  String? _resolvePackageExports(String packageRoot, String? subpath,
      Map<String, dynamic> packageManifest, String packageName) {
    var exports = packageManifest['exports'] as Object?;
    if (exports == null) return null;
    var subpathVariants = _exportsToCheck(subpath);
    if (_nodePackageExportsResolve(
            packageRoot, subpathVariants, exports, subpath, packageName)
        case var path?) {
      return path;
    }

    if (subpath != null && p.extension(subpath).isNotEmpty) return null;

    var subpathIndexVariants = _exportsToCheck(subpath, addIndex: true);
    if (_nodePackageExportsResolve(
            packageRoot, subpathIndexVariants, exports, subpath, packageName)
        case var path?) {
      return path;
    }

    return null;
  }

  /// Returns the path to one subpath variant, resolved in the `exports` of a
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
    if (exports is Map<String, dynamic> &&
        exports.keys.any((key) => key.startsWith('.')) &&
        exports.keys.any((key) => !key.startsWith('.'))) {
      throw '`exports` in $packageName can not have both conditions and paths '
          'at the same level.\n'
          'Found ${exports.keys.map((key) => '"$key"').join(',')} in '
          '${p.join(packageRoot, 'package.json')}.';
    }
    String? processVariant(String? variant) {
      if (variant == null) {
        return _getMainExport(exports).andThen((mainExport) =>
            _packageTargetResolve(variant, mainExport, packageRoot));
      }
      if (exports is! Map<String, dynamic> ||
          exports.keys.every((key) => !key.startsWith('.'))) {
        return null;
      }
      var matchKey = "./${p.toUri(variant)}";
      if (exports.containsKey(matchKey) &&
          exports[matchKey] != null &&
          !matchKey.contains('*')) {
        return _packageTargetResolve(
            matchKey, exports[matchKey] as Object, packageRoot);
      }

      var expansionKeys = [
        for (var key in exports.keys)
          if ('*'.allMatches(key).length == 1) key
      ]..sort(_compareExpansionKeys);

      for (var expansionKey in expansionKeys) {
        var [patternBase, patternTrailer] = expansionKey.split('*');
        if (!matchKey.startsWith(patternBase)) continue;
        if (matchKey == patternBase) continue;
        if (patternTrailer.isEmpty ||
            (matchKey.endsWith(patternTrailer) &&
                matchKey.length >= expansionKey.length)) {
          var target = exports[expansionKey] as Object?;
          if (target == null) continue;
          var patternMatch = matchKey.substring(
              patternBase.length, matchKey.length - patternTrailer.length);
          return _packageTargetResolve(
              variant, target, packageRoot, patternMatch);
        }
      }

      return null;
    }

    var matches = subpathVariants.map(processVariant).whereNotNull().toList();

    return switch (matches) {
      [var path] => path,
      [_, _, ...] && var paths =>
        throw "Unable to determine which of multiple potential resolutions "
            "found for ${subpath ?? 'root'} in $packageName should be used. "
            "\n\nFound:\n"
            "${paths.join('\n')}",
      _ => null
    };
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
      case String string when !string.startsWith('./'):
        throw "Export '$string' must be a path relative to the package root at '$packageRoot'.";
      case String string when patternMatch != null:
        var replaced = string.replaceFirst('*', patternMatch);
        var path = p.normalize(p.join(packageRoot, replaced));
        return fileExists(path) ? path : null;
      case String string:
        return p.join(packageRoot, string);
      case Map<String, dynamic> map:
        for (var (key, value) in map.pairs) {
          if (!const {'sass', 'style', 'default'}.contains(key)) continue;
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
    return switch (exports) {
      String string => string,
      List<String> list => list,
      Map<String, dynamic> map
          when !map.keys.any((key) => key.startsWith('.')) =>
        map,
      Map<String, dynamic> map when map.containsKey('.') && map['.'] != null =>
        map['.'] as Object,
      _ => null
    };
  }

  /// Returns a list of all possible variations of `subpath` with extensions and
  /// partials.
  ///
  /// If there is no subpath, returns a single `null` value, which is used in
  /// `_nodePackageExportsResolve` to denote the main package export.
  List<String?> _exportsToCheck(String? subpath, {bool addIndex = false}) {
    var paths = <String>[];

    if (subpath == null && addIndex) {
      subpath = 'index';
    } else if (subpath != null && addIndex) {
      subpath = p.join(subpath, 'index');
    }
    if (subpath == null) return [null];

    if (const {'.scss', '.sass', '.css'}.contains(p.extension(subpath))) {
      paths.add(subpath);
    } else {
      paths.addAll([
        '$subpath.scss',
        '$subpath.sass',
        '$subpath.css',
      ]);
    }
    var basename = p.basename(subpath);
    var dirname = p.dirname(subpath);

    if (basename.startsWith('_')) return paths;

    return [
      ...paths,
      for (var path in paths)
        if (dirname == '.')
          '_${p.basename(path)}'
        else
          p.join(dirname, '_${p.basename(path)}')
    ];
  }
}
