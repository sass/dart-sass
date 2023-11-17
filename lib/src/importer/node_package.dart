// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../importer.dart';
import './utils.dart';
import 'dart:convert';
import '../io.dart';
import 'package:path/path.dart' as p;

/// A filesystem importer to use for load implementation details, and for
/// canonicalizing paths not defined in package.json.
final _filesystemImporter = FilesystemImporter.cwd;

/// An [Importer] that resolves `pkg:` URLs using the Node resolution algorithm.
class NodePackageImporterInternal extends Importer {
  final Uri entryPointURL;

  /// Creates a Node Package Importer with the associated entry point url
  NodePackageImporterInternal(this.entryPointURL);

  @override
  bool isNonCanonicalScheme(String scheme) {
    return scheme == 'pkg';
  }

  @override
  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') return _filesystemImporter.canonicalize(url);
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

    var baseURL = containingUrl?.scheme == 'file'
        ? Uri.parse(containingUrl!.toFilePath())
        : entryPointURL;

    var (packageName, subpath) = _packageNameAndSubpath(url.path);
    var packageRoot = _resolvePackageRoot(packageName, baseURL);
    if (packageRoot == null) {
      return null;
    }

    // Attempt to resolve using conditional exports
    var jsonPath = p.join(packageRoot.toFilePath(), 'package.json');
    var jsonFile = Uri.file(jsonPath).toFilePath();

    var jsonString = readFile(jsonFile);
    var packageManifest = jsonDecode(jsonString) as Map<String, dynamic>;

    var resolved = _resolvePackageExports(
        packageRoot, subpath, packageManifest, packageName);

    if (resolved != null &&
        resolved.scheme == 'file' &&
        ['.scss', '.sass', '.css'].contains(p.extension(resolved.path))) {
      return resolved;
    } else if (resolved != null) {
      throw "The export for '${subpath == '' ? "root" : subpath}' in "
          "'$packageName' is not a valid Sass file.";
    }
    // If no subpath, attempt to resolve `sass` or `style` key in package.json,
    // then `index` file at package root, resolved for file extensions and
    // partials.
    if (subpath == '') {
      return _resolvePackageRootValues(
          packageRoot.toFilePath(), packageManifest);
    }

    // If there is a subpath, attempt to resolve the path relative to the
    // package root, and resolve for file extensions and partials.
    var relativeSubpath = "${packageRoot.toFilePath()}${p.separator}$subpath";
    return _filesystemImporter.canonicalize(Uri.file(relativeSubpath));
  }

  @override
  ImporterResult? load(Uri url) => _filesystemImporter.load(url);

  /// Takes a string, `path`, and returns a tuple with the package name and the
  /// subpath if it is present.
  (String, String) _packageNameAndSubpath(String path) {
    var parts = path.split('/');
    var name = parts.removeAt(0);
    if (name.startsWith('@')) {
      name = '$name/${parts.removeAt(0)}';
    }
    return (name, parts.isNotEmpty ? parts.join('/') : '');
  }

  /// Takes a string, `packageName`, and an absolute URL `baseURL`, and returns
  /// an absolute URL to the root directory for the most proximate installed
  /// `packageName`.
  Uri? _resolvePackageRoot(String packageName, Uri baseURL) {
    var baseDirectory = isWindows
        ? p.dirname(Uri.directory(baseURL.toString()).toFilePath())
        : p.dirname(baseURL.toFilePath());
    var lastEntry = '';

    Uri? recurseUpFrom(String entry) {
      // prevent infinite recursion
      if (entry == lastEntry) return null;
      lastEntry = entry;
      var potentialPackage = p.joinAll([entry, 'node_modules', packageName]);

      if (dirExists(potentialPackage)) {
        return Uri.directory(potentialPackage);
      }

      var parent = parentDir(entry);
      List<String> parentDirectoryParts =
          List.from(Uri.directory(parent).pathSegments);

      if (parentDirectoryParts.length == 1) return null;
      return recurseUpFrom(parent);
    }

    return recurseUpFrom(baseDirectory);
  }

  /// Takes a string `packagePath`, which is the root directory for a package,
  /// and `packageManifest`, which is the contents of that package's
  /// `package.json` file, and returns a file URL.
  Uri? _resolvePackageRootValues(
      String packageRoot, Map<String, dynamic> packageManifest) {
    var extensions = ['.scss', '.sass', '.css'];

    var sassValue = packageManifest['sass'] as String?;
    if (sassValue != null && extensions.contains(p.extension(sassValue))) {
      return Uri.file('$packageRoot$sassValue');
    }
    var styleValue = packageManifest['style'] as String?;
    if (styleValue != null && extensions.contains(p.extension(styleValue))) {
      return Uri.file('$packageRoot$styleValue');
    }

    var result = resolveImportPath('${packageRoot}index');
    if (result != null) return Uri.file(result);
    return null;
  }

  /// Takes a package.json value `packageManifest`, a directory URL
  /// `packageRoot` and a relative URL path `subpath`. It returns a file URL or
  /// null. `packageName` is used for error reporting only.
  Uri? _resolvePackageExports(Uri packageRoot, String subpath,
      Map<String, dynamic> packageManifest, String packageName) {
    if (packageManifest['exports'] == null) return null;
    var exports = packageManifest['exports'] as Object;
    var subpathVariants = _exportLoadPaths(subpath);
    var resolvedPaths =
        _nodePackageExportsResolve(packageRoot, subpathVariants, exports);

    if (resolvedPaths.length == 1) return resolvedPaths.first;
    if (resolvedPaths.length > 1) {
      throw "Unable to determine which of multiple potential "
          "resolutions found for $subpath in $packageName should be used.";
    }
    if (p.extension(subpath).isNotEmpty) return null;

    var subpathIndexVariants = _exportLoadPaths(subpath, true);

    var resolvedIndexpaths =
        _nodePackageExportsResolve(packageRoot, subpathIndexVariants, exports);

    if (resolvedIndexpaths.length == 1) return resolvedIndexpaths.first;
    if (resolvedIndexpaths.length > 1) {
      throw "Unable to determine which of multiple potential "
          "resolutions found for $subpath in $packageName should be used.";
    }

    return null;
  }

  /// Takes a package.json value `packageManifest`, a directory URL
  /// `packageRoot` and a list of relative URL paths `subpathVariants`. It
  /// returns a list of all subpaths present in the package manifest exports.
  List<Uri> _nodePackageExportsResolve(
      Uri packageRoot, List<String> subpathVariants, Object exports) {
    Uri? processVariant(String subpath) {
      if (subpath == '') {
        Object? mainExport = _getMainExport(exports);
        if (mainExport == null) return null;
        return _packageTargetResolve(subpath, mainExport, packageRoot);
      } else {
        if (exports is Map<String, dynamic> &&
            exports.keys.every((key) => key.startsWith('.'))) {
          var matchKey = subpath.startsWith('/') ? ".$subpath" : "./$subpath";
          if (exports.containsKey(matchKey) && !matchKey.contains('*')) {
            return _packageTargetResolve(
                matchKey, exports[matchKey] as Object, packageRoot);
          }

          var expansionKeys = exports.keys.where(
              (key) => key.split('').where((char) => char == '*').length == 1);
          expansionKeys = _sortExpansionKeys(expansionKeys.toList());

          for (var expansionKey in expansionKeys) {
            var parts = expansionKey.split('*');
            var patternBase = parts[0];
            if (matchKey.startsWith(patternBase) && matchKey != patternBase) {
              var patternTrailer = parts[1];
              if (patternTrailer.isEmpty ||
                  (matchKey.endsWith(patternTrailer) &&
                      matchKey.length >= expansionKey.length)) {
                var target = exports[expansionKey] as Object;
                var patternMatch = matchKey.substring(patternBase.length,
                    matchKey.length - patternTrailer.length);
                return _packageTargetResolve(
                    subpath, target, packageRoot, patternMatch);
              }
            }
          }
        }
      }
      return null;
    }

    return subpathVariants.map(processVariant).whereNotNull().toList();
  }

  /// Implementation of the `PATTERN_KEY_COMPARE` algorithm from
  /// https://nodejs.org/api/esm.html#resolution-algorithm-specification.
  List<String> _sortExpansionKeys(List<String> keys) {
    int sorter(String keyA, String keyB) {
      var baseLengthA =
          keyA.contains('*') ? keyA.indexOf('*') + 1 : keyA.length;
      var baseLengthB =
          keyB.contains('*') ? keyB.indexOf('*') + 1 : keyB.length;
      if (baseLengthA > baseLengthB) return -1;
      if (baseLengthB > baseLengthA) return 1;
      if (!keyA.contains("*")) return 1;
      if (!keyB.contains("*")) return -1;
      if (keyA.length > keyB.length) return -1;
      if (keyB.length > keyA.length) return 1;
      return 0;
    }

    keys.sort(sorter);
    return keys;
  }

  /// Recurses through `exports` object to find match for `subpath`.
  Uri? _packageTargetResolve(String subpath, Object exports, Uri packageRoot,
      [String? patternMatch]) {
    switch (exports) {
      case String string:
        if (!string.startsWith('./')) {
          throw "Invalid Package Target";
        }
        if (patternMatch != null) {
          string = string.replaceAll(RegExp(r'\*'), patternMatch);
          var path = p.normalize("${packageRoot.toFilePath()}/$string");
          if (fileExists(path)) {
            return Uri.parse('$packageRoot/$string');
          } else {
            return null;
          }
        }
        return Uri.parse("$packageRoot/$string");
      case Map<String, dynamic> map:
        var conditions = ['sass', 'style', 'default'];
        for (var key in map.keys) {
          if (conditions.contains(key)) {
            var result = _packageTargetResolve(
                subpath, map[key] as Object, packageRoot, patternMatch);
            if (result != null) {
              return result;
            }
          }
        }
        return null;
      case List<dynamic> array:
        if (array.isEmpty) return null;

        for (var value in array) {
          var result = _packageTargetResolve(
              subpath, value as Object, packageRoot, patternMatch);
          if (result != null) {
            return result;
          }
        }

        return null;
      default:
        break;
    }
    return null;
  }

  /// Given an `exports` object, returns the entry for an export without a
  /// subpath.
  Object? _getMainExport(Object exports) {
    switch (exports) {
      case String string:
        return string;

      case List<String> list:
        return list;

      case Map<String, dynamic> map:
        if (!map.keys.any((key) => key.startsWith('.'))) {
          return map;
        } else if (map.containsKey('.')) {
          return map['.'] as Object;
        }
        break;
      default:
        break;
    }
    return null;
  }

  /// Given a string `subpath`, returns a list of all possible variations with
  /// extensions and partials.
  List<String> _exportLoadPaths(String subpath, [bool addIndex = false]) {
    List<String> paths = [];
    if (subpath.isEmpty && !addIndex) return [subpath];
    if (subpath.isEmpty && addIndex) {
      subpath = 'index';
    } else if (subpath.isNotEmpty && addIndex) {
      subpath = "$subpath/index";
    }

    if (['scss', 'sass', 'css'].any((ext) => subpath.endsWith(ext))) {
      paths.add(subpath);
    } else {
      paths.addAll([
        '$subpath.scss',
        '$subpath.sass',
        '$subpath.css',
      ]);
    }
    var subpathSegments = Uri.parse(subpath).pathSegments;
    var basename = subpathSegments.last;
    var dirPath = subpathSegments.sublist(0, subpathSegments.length - 1);
    if (!basename.startsWith('_')) {
      List<String> prefixedPaths = [];
      for (final path in paths) {
        var pathBasename = Uri.parse(path).pathSegments.last;
        if (dirPath.isEmpty) {
          prefixedPaths.add('_$pathBasename');
        } else {
          prefixedPaths.add('${dirPath.join(p.separator)}/_$pathBasename');
        }
      }
      paths.addAll(prefixedPaths);
    }
    return paths;
  }
}
