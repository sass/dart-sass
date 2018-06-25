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
///   2. Filesystem imports relative to the working directory.
///   3. Filesystem imports relative to an `includePaths` path.
///   4. Custom importer imports.
class NodeImporter {
  /// The `this` context in which importer functions are invoked.
  final Object _context;

  /// The include paths passed in by the user.
  final List<String> _includePaths;

  /// The importer functions passed in by the user.
  final List<JSFunction> _importers;

  NodeImporter(this._context, Iterable<String> includePaths, Iterable importers)
      : _includePaths = new List.unmodifiable(includePaths),
        _importers = new List.unmodifiable(importers);

  /// Loads the stylesheet at [url].
  ///
  /// The [previous] URL is the URL of the stylesheet in which the import
  /// appeared. Returns the contents of the stylesheet and the URL to use as
  /// [previous] for imports within the loaded stylesheet.
  Tuple2<String, String> load(String url, Uri previous) {
    var parsed = Uri.parse(url);
    if (parsed.scheme == '' || parsed.scheme == 'file') {
      var result = _resolvePath(p.fromUri(parsed), previous);
      if (result != null) return result;
    }

    // The previous URL is always an absolute file path for filesystem imports.
    var previousString =
        previous.scheme == 'file' ? p.fromUri(previous) : previous.toString();
    for (var importer in _importers) {
      var value = call2(importer, _context, url, previousString);
      if (value != null) return _handleImportResult(url, previous, value);
    }

    return null;
  }

  /// Asynchronously loads the stylesheet at [url].
  ///
  /// The [previous] URL is the URL of the stylesheet in which the import
  /// appeared. Returns the contents of the stylesheet and the URL to use as
  /// [previous] for imports within the loaded stylesheet.
  Future<Tuple2<String, String>> loadAsync(String url, Uri previous) async {
    var parsed = Uri.parse(url);
    if (parsed.scheme == '' || parsed.scheme == 'file') {
      var result = _resolvePath(p.fromUri(parsed), previous);
      if (result != null) return result;
    }

    // The previous URL is always an absolute file path for filesystem imports.
    var previousString =
        previous.scheme == 'file' ? p.fromUri(previous) : previous.toString();
    for (var importer in _importers) {
      var value = await _callImporterAsync(importer, url, previousString);
      if (value != null) return _handleImportResult(url, previous, value);
    }

    return null;
  }

  /// Tries to load a stylesheet at the given [path] using Node Sass's file path
  /// resolution logic.
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String> _resolvePath(String path, Uri previous) {
    if (p.isAbsolute(path)) return _tryPath(path);

    // 1: Filesystem imports relative to the base file.
    if (previous.scheme == 'file') {
      var result = _tryPath(p.join(p.dirname(p.fromUri(previous)), path));
      if (result != null) return result;
    }

    // 2: Filesystem imports relative to the working directory.
    var cwdResult = _tryPath(p.absolute(path));
    if (cwdResult != null) return cwdResult;

    // 3: Filesystem imports relative to [_includePaths].
    for (var includePath in _includePaths) {
      var result = _tryPath(p.absolute(p.join(includePath, path)));
      if (result != null) return result;
    }

    return null;
  }

  /// Tries to load a stylesheet at the given [path].
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String> _tryPath(String path) {
    var resolved = resolveImportPath(path);
    return resolved == null
        ? null
        : new Tuple2(readFile(resolved), p.toUri(resolved).toString());
  }

  /// Converts an importer's return [value] to a tuple that can be returned by
  /// [load].
  Tuple2<String, String> _handleImportResult(
      String url, Uri previous, Object value) {
    if (isJSError(value)) throw value;

    NodeImporterResult result;
    try {
      result = value as NodeImporterResult;
    } on CastError {
      // is reports a different result than as here. I can't find a minimal
      // reproduction, but it seems likely to be related to sdk#26838.
      return null;
    }

    if (result.file != null) {
      var resolved = _resolvePath(result.file, previous);
      if (resolved != null) return resolved;

      throw "Can't find stylesheet to import.";
    } else {
      return new Tuple2(result.contents ?? '', url);
    }
  }

  /// Calls an importer that may or may not be asynchronous.
  Future<Object> _callImporterAsync(
      JSFunction importer, String url, String previousString) async {
    var completer = new Completer();

    var result = call3(importer, _context, url, previousString,
        allowInterop(completer.complete));
    if (isUndefined(result)) return await completer.future;
    return result;
  }
}
