// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../importer.dart';
import './utils.dart';
import 'dart:convert';
import '../io.dart';
import 'package:path/path.dart' as p;

/// A filesystem importer to use for load implementation details, and for
/// canonicalizing paths not defined in package.json.
///
final _filesystemImporter = FilesystemImporter('.');

// An importer that resolves `pkg:` URLs using the Node resolution algorithm.
class NodePackageImporterInternal extends Importer {
  final Uri entryPointURL;
  // Creates an importer with the associated entry point url
  NodePackageImporterInternal(this.entryPointURL);

  @override
  Uri? canonicalize(Uri url) {
    if (url.scheme != 'pkg') return null;
    if (url.path.startsWith('/')) {
      throw "pkg: URL $url must not be an absolute path";
    }
    if (url.path.isEmpty) {
      throw "pkg: URL $url must not have an empty path";
    }
    if (url.userInfo != '' || url.hasPort || url.hasQuery || url.hasFragment) {
      throw "Invalid URL $url";
    }
    var baseURL =
        containingUrl?.scheme == 'file:' ? containingUrl! : entryPointURL;

    var (packageName, subpath) = packageNameAndSubpath(url.path);
    var packageRoot = resolvePackageRoot(packageName, baseURL);
    if (packageRoot == null) {
      throw "Node Package '$packageName' could not be found.";
    }

    // Attempt to resolve using conditional exports
    var jsonString = readFile(packageRoot.path + '/package.json');
    var packageManifest = jsonDecode(jsonString) as Map<String, dynamic>;

    var resolved = resolvePackageExports(
        packageRoot, subpath, packageManifest, packageName);

    if (resolved != null &&
        resolved.scheme == 'file:' &&
        ['scss', 'sass', 'css'].contains(p.extension(resolved.path))) {
      return resolved;
    } else if (resolved != null) {
      throw "The export for $subpath in $packageName is not a valid Sass file.";
    }
    // If no subpath, attempt to resolve `sass` or `style` key in package.json,
    // then `index` file at package root, resolved for file extensions and
    // partials.
    if (subpath == '') {
      return resolvePackageRootValues(packageRoot.path, packageManifest);
    }

    // If there is a subpath, attempt to resolve the path relative to the package root, and
    //  resolve for file extensions and partials.
    return _filesystemImporter
        .canonicalize(Uri.file("${packageRoot.path}/$subpath"));
  }

  @override
  ImporterResult? load(Uri url) => _filesystemImporter.load(url);
}

// Takes a string, `path`, and returns a tuple with the package name and the
// subpath if it is present.
(String, String) packageNameAndSubpath(String path) {
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
Uri? resolvePackageRoot(String packageName, Uri baseURL) {
  var baseDirectory = p.dirname(baseURL.toString());

  // TODO make recursive
  var potentialPackage =
      p.joinAll([baseDirectory, 'node_modules', packageName]);

  if (dirExists(potentialPackage)) {
    return Uri.parse(potentialPackage);
  }
  return null;
}

// Takes a string `packagePath`, which is the root directory for a package, and
// `packageManifest`, which is the contents of that package's `package.json`
// file, and returns a file URL.
Uri? resolvePackageRootValues(
    String packageRoot, Map<String, dynamic> packageManifest) {
  var extensions = ['.scss', '.sass', '.css'];

  var sassValue = packageManifest['sass'] as String?;
  if (sassValue != null && extensions.contains(p.extension(sassValue))) {
    return Uri.file('$packageRoot/$sassValue');
  }
  var styleValue = packageManifest['style'] as String?;
  if (styleValue != null && extensions.contains(p.extension(styleValue))) {
    return Uri.file('$packageRoot/$styleValue');
  }

  var result = resolveImportPath('$packageRoot/index');
  if (result != null) return Uri.file(result);
  return null;
}

// Takes a package.json value `packageManifest`, a directory URL `packageRoot`
// and a relative URL path `subpath`. It returns a file URL or null.
// `packageName` is used for error reporting only.
Uri? resolvePackageExports(Uri packageRoot, String subpath,
    Map<String, dynamic> packageManifest, String packageName) {
  if (packageManifest['exports'] == null) return null;
  var exports = packageManifest['exports'] as Map<String, dynamic>;
  var subpathVariants = exportLoadPaths(subpath);
  var resolvedPaths =
      nodePackageExportsResolve(packageRoot, subpathVariants, exports);

  if (resolvedPaths.length == 1) return resolvedPaths.first;
  if (resolvedPaths.length > 1) {
    throw "Unable to determine which of multiple potential"
        "resolutions found for $subpath in $packageName should be used.";
  }
  if (p.extension(subpath).isNotEmpty) return null;

  var subpathIndexVariants = exportLoadPaths("$subpath/index");

  var resolvedIndexpaths =
      nodePackageExportsResolve(packageRoot, subpathIndexVariants, exports);

  if (resolvedIndexpaths.length == 1) return resolvedPaths.first;
  if (resolvedIndexpaths.length > 1) {
    throw "Unable to determine which of multiple potential"
        "resolutions found for $subpath in $packageName should be used.";
  }

  return null;
}

// Takes a package.json value `packageManifest`, a directory URL `packageRoot`
// and a list of relative URL paths `subpathVariants`. It returns a list of all
// subpaths present in the package Manifest exports.
List<Uri> nodePackageExportsResolve(Uri packageRoot,
    List<String> subpathVariants, Map<String, dynamic> exports) {
  // TODO implement
  return [];
}

// Given a string `subpath`, returns a list of all possible variations with
// extensions and partials.
List<String> exportLoadPaths(String subpath) {
  List<String> paths = [];

  if (['scss', 'sass', 'css'].any((ext) => subpath.endsWith(ext))) {
    paths.add(subpath);
  } else {
    paths.addAll([
      '$subpath.scss',
      '$subpath.sass',
      '$subpath.css',
    ]);
  }
  var basename = Uri.parse(subpath).pathSegments.last;
  if (!basename.startsWith('_')) {
    List<String> prefixedPaths = [];
    for (final path in paths) {
      prefixedPaths.add('_$path');
    }
    paths.addAll(prefixedPaths);
  }

  return paths;
}
