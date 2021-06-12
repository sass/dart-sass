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
import '../../util/nullable.dart';
import '../../node/render_context.dart';
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
  /// The options for the `this` context in which importer functions are
  /// invoked.
  ///
  /// This is typed as [Object] because the public interface of [NodeImporter]
  /// is shared with the VM, which can't handle JS interop types.
  final Object _options;

  /// The include paths passed in by the user.
  final List<String> _includePaths;

  /// The importer functions passed in by the user.
  final List<JSFunction> _importers;

  NodeImporter(
      this._options, Iterable<String> includePaths, Iterable<Object> importers)
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

  /// Loads the stylesheet at [url] relative to [previous] if possible.
  ///
  /// This can also load [url] directly if it's an absolute `file:` URL, even if
  /// `previous` isn't defined or isn't a `file:` URL.
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String>? loadRelative(
      String url, Uri? previous, bool forImport) {
    if (p.url.isAbsolute(url)) {
      if (!url.startsWith('/') && !url.startsWith('file:')) return null;
      return _tryPath(p.fromUri(url), forImport);
    }

    if (previous?.scheme != 'file') return null;

    // 1: Filesystem imports relative to the base file.
    return _tryPath(
        p.join(p.dirname(p.fromUri(previous)), p.fromUri(url)), forImport);
  }

  /// Loads the stylesheet at [url] from an importer or load path.
  ///
  /// The [previous] URL is the URL of the stylesheet in which the import
  /// appeared. Returns the contents of the stylesheet and the URL to use as
  /// [previous] for imports within the loaded stylesheet.
  Tuple2<String, String>? load(String url, Uri? previous, bool forImport) {
    // The previous URL is always an absolute file path for filesystem imports.
    var previousString = _previousToString(previous);
    for (var importer in _importers) {
      var value =
          call2(importer, _renderContext(forImport), url, previousString);
      if (value != null) {
        return _handleImportResult(url, previous, value, forImport);
      }
    }

    return _resolveLoadPathFromUrl(Uri.parse(url), forImport);
  }

  /// Asynchronously loads the stylesheet at [url] from an importer or load
  /// path.
  ///
  /// The [previous] URL is the URL of the stylesheet in which the import
  /// appeared. Returns the contents of the stylesheet and the URL to use as
  /// [previous] for imports within the loaded stylesheet.
  Future<Tuple2<String, String>?> loadAsync(
      String url, Uri? previous, bool forImport) async {
    // The previous URL is always an absolute file path for filesystem imports.
    var previousString = _previousToString(previous);
    for (var importer in _importers) {
      var value =
          await _callImporterAsync(importer, url, previousString, forImport);
      if (value != null) {
        return _handleImportResult(url, previous, value, forImport);
      }
    }

    return _resolveLoadPathFromUrl(Uri.parse(url), forImport);
  }

  /// Converts [previous] to a string to pass to the importer function.
  String _previousToString(Uri? previous) {
    if (previous == null) return 'stdin';
    if (previous.scheme == 'file') return p.fromUri(previous);
    return previous.toString();
  }

  /// Tries to load a stylesheet at the given [url] from a load path (including
  /// the working directory), if that URL refers to the filesystem.
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String>? _resolveLoadPathFromUrl(Uri url, bool forImport) =>
      url.scheme == '' || url.scheme == 'file'
          ? _resolveLoadPath(p.fromUri(url), forImport)
          : null;

  /// Tries to load a stylesheet at the given [path] from a load path (including
  /// the working directory).
  ///
  /// Returns the stylesheet at that path and the URL used to load it, or `null`
  /// if loading failed.
  Tuple2<String, String>? _resolveLoadPath(String path, bool forImport) {
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
  Tuple2<String, String>? _tryPath(String path, bool forImport) => (forImport
          ? inImportRule(() => resolveImportPath(path))
          : resolveImportPath(path))
      .andThen((resolved) =>
          Tuple2(readFile(resolved), p.toUri(resolved).toString()));

  /// Converts an importer's return [value] to a tuple that can be returned by
  /// [load].
  Tuple2<String, String>? _handleImportResult(
      String url, Uri? previous, Object value, bool forImport) {
    if (isJSError(value)) throw value;
    if (value is! NodeImporterResult) return null;

    var file = value.file;
    var contents = value.contents;
    if (file == null) {
      return Tuple2(contents ?? '', url);
    } else if (contents != null) {
      return Tuple2(contents, file);
    } else {
      var resolved =
          loadRelative(p.toUri(file).toString(), previous, forImport) ??
              _resolveLoadPath(file, forImport);
      if (resolved != null) return resolved;
      throw "Can't find stylesheet to import.";
    }
  }

  /// Calls an importer that may or may not be asynchronous.
  Future<Object?> _callImporterAsync(JSFunction importer, String url,
      String previousString, bool forImport) async {
    var completer = Completer<Object>();

    var result = call3(importer, _renderContext(forImport), url, previousString,
        allowInterop(completer.complete));
    if (isUndefined(result)) return await completer.future;
    return result;
  }

  /// Returns the [RenderContext] in which to invoke importers.
  RenderContext _renderContext(bool fromImport) {
    var context = RenderContext(
        options: _options as RenderContextOptions, fromImport: fromImport);
    context.options.context = context;
    return context;
  }
}
