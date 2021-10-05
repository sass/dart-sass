// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';
import 'package:path/path.dart' as p;

import '../../io.dart' as io;
import '../../importer.dart';
import '../../node/importer.dart';
import '../../node/utils.dart';
import '../../syntax.dart';
import '../filesystem.dart';
import '../result.dart';
import '../utils.dart';

/// A filesystem importer to use for most implementation details of
/// [NodeToDartAsyncFileImporter].
///
/// This allows us to avoid duplicating logic between the two importers.
final _filesystemImporter = FilesystemImporter('.');

/// A wrapper for a potentially-asynchronous JS API file importer that exposes
/// it as a Dart [AsyncImporter].
class NodeToDartFileImporter extends Importer {
  /// The wrapped `findFileUrl` function.
  final Object? Function(String, CanonicalizeOptions) _findFileUrl;

  /// A map from canonical URLs to the `sourceMapUrl`s associated with them.
  final _sourceMapUrls = <Uri, Uri>{};

  NodeToDartFileImporter(this._findFileUrl);

  Uri? canonicalize(Uri url) {
    if (url.scheme != 'file' && url.scheme != '') return null;

    var result = _findFileUrl(
        url.toString(), CanonicalizeOptions(fromImport: fromImport));
    if (result == null) return null;

    if (isPromise(result)) {
      jsThrow(JsError(
          "The canonicalize() function can't return a Promise for synchronous "
          "compile functions."));
    }

    result as NodeFileImporterResult;
    var dartUrl = result.url;
    var sourceMapUrl = result.sourceMapUrl;
    if (dartUrl == null) {
      jsThrow(JsError(
          "The findFileUrl() method must return an object a url field."));
    }

    var resultUrl = jsToDartUrl(dartUrl);
    if (resultUrl.scheme != 'file') {
      jsThrow(JsError(
          'The findFileUrl() must return a URL with scheme file://, was '
          '"$url".'));
    }

    var canonical = _filesystemImporter.canonicalize(resultUrl);
    if (canonical == null) return null;
    if (sourceMapUrl != null) {
      _sourceMapUrls[canonical] = jsToDartUrl(sourceMapUrl);
    }

    return canonical;
  }

  ImporterResult? load(Uri url) {
    var path = p.fromUri(url);
    return ImporterResult(io.readFile(path),
        sourceMapUrl: _sourceMapUrls[url] ?? url, syntax: Syntax.forPath(path));
  }

  DateTime modificationTime(Uri url) =>
      _filesystemImporter.modificationTime(url);

  bool couldCanonicalize(Uri url, Uri canonicalUrl) =>
      _filesystemImporter.couldCanonicalize(url, canonicalUrl);
}
