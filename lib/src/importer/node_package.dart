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
///
final _filesystemImporter = FilesystemImporter('.');

/// An importer that resolves `pkg:` URLs using the Node resolution algorithm.
class NodePackageImporterInternal extends Importer {
  final Uri entryPointURL;
  // Creates an importer with the associated entry point url
  NodePackageImporterInternal(this.entryPointURL);

  @override
  bool isNonCanonicalScheme(String scheme) {
    return scheme == 'pkg';
  }

  @override
  Uri? canonicalize(Uri url) {
    if (url.scheme != 'pkg') return null;
    // TODO(jamesnw) Can these errors even be thrown? Or are these cases
    // filtered out before this?
    if (url.path.startsWith('/')) {
      throw "pkg: URL $url must not be an absolute path.";
    }
    if (url.path.isEmpty) {
      throw "pkg: URL $url must not have an empty path.";
    }
    if (url.userInfo != '' || url.hasPort || url.hasQuery || url.hasFragment) {
      throw "Invalid URL $url";
    }
    var baseURL =
        containingUrl?.scheme == 'file' ? containingUrl! : entryPointURL;

    var (packageName, subpath) = _packageNameAndSubpath(url.path);
    var packageRoot = _resolvePackageRoot(packageName, baseURL);
    if (packageRoot == null) {
      throw "Node Package '$packageName' could not be found.";
    }

    // Attempt to resolve using conditional exports
    var jsonString = readFile(packageRoot.path + '/package.json');
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
      return _resolvePackageRootValues(packageRoot.path, packageManifest);
    }

    // If there is a subpath, attempt to resolve the path relative to the package root, and
    //  resolve for file extensions and partials.
    return _filesystemImporter
        .canonicalize(Uri.file("${packageRoot.path}${p.separator}$subpath"));
  }

  @override
  ImporterResult? load(Uri url) => _filesystemImporter.load(url);

  // Takes a string, `path`, and returns a tuple with the package name and the
  // subpath if it is present.
  (String, String) _packageNameAndSubpath(String path) {
    var parts = path.split('/');
    var name = parts.removeAt(0);
    if (name.startsWith('@')) {
      name = '$name/${parts.removeAt(0)}';
    }
    return (name, parts.isNotEmpty ? parts.join('/') : '');
  }

  // Takes a string, `packageName`, and an absolute URL `baseURL`, and returns an
  // absolute URL to the root directory for the most proximate installed
  // `packageName`.
  Uri? _resolvePackageRoot(String packageName, Uri baseURL) {
    var baseDirectory = p.dirname(Uri.file(baseURL.toString()).toFilePath());
    print("baseDirectory: $baseDirectory, baseURL: $baseURL");
    Uri? recurseUpFrom(String entry) {
      if (!entry.startsWith(p.separator)) entry = "${p.separator}$entry";
      var potentialPackage = p.joinAll([entry, 'node_modules', packageName]);
      print("potentialPackage: $potentialPackage");
      if (dirExists(potentialPackage)) {
        return Uri.file(potentialPackage);
      }
      List<String> parentDirectoryParts =
          List.from(Uri.parse(entry).pathSegments)..removeLast();

      if (parentDirectoryParts.isEmpty) return null;

      return recurseUpFrom(p.joinAll(parentDirectoryParts));
    }

    return recurseUpFrom(baseDirectory);
  }

  // Takes a string `packagePath`, which is the root directory for a package, and
  // `packageManifest`, which is the contents of that package's `package.json`
  // file, and returns a file URL.
  Uri? _resolvePackageRootValues(
      String packageRoot, Map<String, dynamic> packageManifest) {
    var extensions = ['.scss', '.sass', '.css'];

    var sassValue = packageManifest['sass'] as String?;
    if (sassValue != null && extensions.contains(p.extension(sassValue))) {
      return Uri.file('$packageRoot/$sassValue');
    }
    var styleValue = packageManifest['style'] as String?;
    if (styleValue != null && extensions.contains(p.extension(styleValue))) {
      return Uri.file('$packageRoot${p.separator}$styleValue');
    }

    var result = resolveImportPath('$packageRoot${p.separator}index');
    if (result != null) return Uri.file(result);
    return null;
  }

  // Takes a package.json value `packageManifest`, a directory URL `packageRoot`
  // and a relative URL path `subpath`. It returns a file URL or null.
  // `packageName` is used for error reporting only.
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

  // Takes a package.json value `packageManifest`, a directory URL `packageRoot`
  // and a list of relative URL paths `subpathVariants`. It returns a list of all
  // subpaths present in the package Manifest exports.
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
          if (exports.containsKey(matchKey)) {
            return _packageTargetResolve(
                matchKey, exports[matchKey] as Object, packageRoot);
          }
        }
      }
      return null;
    }

    return subpathVariants.map(processVariant).whereNotNull().toList();
  }

  Uri? _packageTargetResolve(String subpath, Object exports, Uri packageRoot) {
    switch (exports) {
      case String string:
        if (!string.startsWith('./')) {
          throw "Invalid Package Target";
        }
        return Uri.parse("$packageRoot/$string");
      case Map<String, dynamic> map:
        var conditions = ['sass', 'style', 'default'];
        for (var key in map.keys) {
          if (conditions.contains(key)) {
            var result =
                _packageTargetResolve(subpath, map[key] as Object, packageRoot);
            if (result != null) {
              return result;
            }
          }
        }
        return null;
      case List<dynamic> array:
        if (array.isEmpty) return null;

        for (var value in array) {
          var result =
              _packageTargetResolve(subpath, value as Object, packageRoot);
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

  // Given a string `subpath`, returns a list of all possible variations with
  // extensions and partials.
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
          prefixedPaths.add('$dirPath/_$pathBasename');
        }
      }
      paths.addAll(prefixedPaths);
    }
    return paths;
  }
}
