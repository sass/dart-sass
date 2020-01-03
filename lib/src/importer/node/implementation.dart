// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import '../../io.dart';
import '../../node/function.dart';
import '../../node/importer_result.dart';
import '../../node/utils.dart';
import '../utils.dart';

/// An importer that encapsulates Node Sass's import logic.
///
/// This isn't a normal [Importer] because Node Sass's import behavior isn't
/// compatible with Dart Sass's. In particular:
///
/// * Rather than doing URL resolution for relative imports, the importer is
///   passed the URL of the file that contains the import which it can then use
///   to do its own relative resolution. It's passed this even if that file was
///   imported by a different importer.
///
/// * Importers can return file paths rather than the contents of the imported
///   file. These paths are made absolute before they're included in
///   [EvaluateResult.includedFiles] or passed as the previous "URL" to other
///   importers.
///
/// * The working directory is always implicitly an include path.
///
/// * The order of import precedence is as follows:
///
///   1. Filesystem imports relative to the base file.
///   2. Custom importer imports.
///   3. Filesystem imports relative to the working directory.
///   4. Filesystem imports relative to an `includePaths` path.
///   5. Filesystem imports relative to a `SASS_PATH` path.
class NodeImporter {
  /// The `this` context in which importer functions are invoked.
  final Object _context;

  /// The include paths passed in by the user.
  final List<String> _includePaths;

  /// The importer functions passed in by the user.
  final List<JSFunction> _importers;

  NodeImporter(
      this._context, Iterable<String> includePaths, Iterable<Object> importers)
      : _includePaths = List.unmodifiable(_addSassPath(includePaths)),
        _importers = List.unmodifiable(importers.cast());

  /// Returns [includePaths] followed by any paths loaded from the `SASS_PATH`
  /// environment variable.
  static Iterable<String> _addSassPath(Iterable<String> includePaths) sync* {
    yield* includePaths;
    var sassPath = getEnvironmentVariable("SASS_PATH");
    if (sassPath == null) return;
    yield* sassPath.split(isWindows ? ';' : ':');
  }

  /// Loads the stylesheet at [url].
  ///
  /// The [previous] URL is the URL of the stylesheet in which the import
  /// appeared. Returns the contents of the stylesheet and the URL to use as
  /// [previous] for imports within the loaded stylesheet.
  Tuple2<String, String> load(String url, Uri previous, bool forImport) {
    var parsed = Uri.parse(url);
    if (parsed.scheme == '' || parsed.scheme == 'file') {
      var result = _resolveRelativePath(p.fromUri(parsed), previous, forImport);
      if (result != null) return result;
    }

    // The previous URL is always an absolute file path for filesystem imports.
    var previousString =
        previous.scheme == 'file' ? p.fromUri(previous) : previous.toString();
    for (var importer in _importers) {
      var value = call2(importer, _context, url, previousString);
      if (value != null) {
        return _handleImportResult(url, previous, value, forImport);
      }
    }

    return _resolveLoadPathFromUrl(parsed, previous, forImport);
  }

  /// Asynchronously loads the stylesheet at [url].
  ///
  /// The [previous] URL is the URL of the stylesheet in which the import
  /// appeared. Returns the contents of the stylesheet and the URL to use as
  /// [previous] for imports within the loaded stylesheet.
  Future<Tuple2<String, String>> loadAsync(
      String url, Uri previous, bool forImport) async {
    var parsed = Uri.parse(url);
    if (parsed.scheme == '' || parsed.scheme == 'file') {
      var result = _resolveRelativePath(p.fromUri(parsed), previous, forImport);
      if (result != null) return result;
    }

    // The previous URL is always an absolute file path for filesystem imports.
    var previousString =
        previous.scheme == 'file' ? p.fromUri(previous) : previous.toString();
    for (var importer in _importers) {
      var value = await _callImporterAsync(importer, url, previousString);
      if (value != null) {
        return _handleImportResult(url, previous, value, forImport);
      }
    }

    return _resolveLoadPathFromUrl(parsed, previous, forImport);
  }

  /// Tries to load a stylesheet at the given [path] relative to [previous].
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String> _resolveRelativePath(
      String path, Uri previous, bool forImport) {
    if (p.isAbsolute(path)) return _tryPath(path, forImport);

    // 1: Filesystem imports relative to the base file.
    if (previous.scheme == 'file') {
      var result =
          _tryPath(p.join(p.dirname(p.fromUri(previous)), path), forImport);
      if (result != null) return result;
    }
    return null;
  }

  /// Tries to load a stylesheet at the given [url] from a load path (including
  /// the working directory), if that URL refers to the filesystem.
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String> _resolveLoadPathFromUrl(
          Uri url, Uri previous, bool forImport) =>
      url.scheme == '' || url.scheme == 'file'
          ? _resolveLoadPath(p.fromUri(url), previous, forImport)
          : null;

  /// Tries to load a stylesheet at the given [path] from a load path (including
  /// the working directory).
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String> _resolveLoadPath(
      String path, Uri previous, bool forImport) {
    // 2: Filesystem imports relative to the working directory.
    var cwdResult = _tryPath(p.absolute(path), forImport);
    if (cwdResult != null) return cwdResult;

    // 3: Filesystem imports relative to [_includePaths].
    for (var includePath in _includePaths) {
      var result = _tryPath(p.absolute(p.join(includePath, path)), forImport);
      if (result != null) return result;
    }

    return null;
  }

  /// Tries to load a stylesheet at the given [path].
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String> _tryPath(String path, bool forImport) {
    var resolved = forImport
        ? inImportRule(() => resolveImportPath(path))
        : resolveImportPath(path);
    return resolved == null
        ? null
        : Tuple2(readFile(resolved), p.toUri(resolved).toString());
  }

  /// Converts an importer's return [value] to a tuple that can be returned by
  /// [load].
  Tuple2<String, String> _handleImportResult(
      String url, Uri previous, Object value, bool forImport) {
    if (isJSError(value)) throw value;
    if (value is! NodeImporterResult) return null;

    var result = value as NodeImporterResult;
    if (result.file != null) {
      var resolved = _resolveRelativePath(result.file, previous, forImport) ??
          _resolveLoadPath(result.file, previous, forImport);
      if (resolved != null) return resolved;

      throw "Can't find stylesheet to import.";
    } else {
      return Tuple2(result.contents ?? '', url);
    }
  }

  /// Calls an importer that may or may not be asynchronous.
  Future<Object> _callImporterAsync(
      JSFunction importer, String url, String previousString) async {
    var completer = Completer<Object>();

    var result = call3(importer, _context, url, previousString,
        allowInterop(completer.complete));
    if (isUndefined(result)) return await completer.future;
    return result;
  }
}
