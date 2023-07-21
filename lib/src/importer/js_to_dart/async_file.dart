// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';

import '../../js/importer.dart';
import '../../js/url.dart';
import '../../js/utils.dart';
import '../async.dart';
import '../filesystem.dart';
import '../result.dart';
import '../utils.dart';

/// A filesystem importer to use for most implementation details of
/// [JSToDartAsyncFileImporter].
///
/// This allows us to avoid duplicating logic between the two importers.
final _filesystemImporter = FilesystemImporter('.');

/// A wrapper for a potentially-asynchronous JS API file importer that exposes
/// it as a Dart [AsyncImporter].
class JSToDartAsyncFileImporter extends AsyncImporter {
  /// The wrapped `findFileUrl` function.
  final Object? Function(String, CanonicalizeOptions) _findFileUrl;

  JSToDartAsyncFileImporter(this._findFileUrl);

  FutureOr<Uri?> canonicalize(Uri url) async {
    if (url.scheme == 'file') return _filesystemImporter.canonicalize(url);

    var result = _findFileUrl(
        url.toString(), CanonicalizeOptions(fromImport: fromImport));
    if (isPromise(result)) result = await promiseToFuture(result as Promise);
    if (result == null) return null;
    if (!isJSUrl(result)) {
      jsThrow(JsError("The findFileUrl() method must return a URL."));
    }

    var resultUrl = jsToDartUrl(result as JSUrl);
    if (resultUrl.scheme != 'file') {
      jsThrow(JsError(
          'The findFileUrl() must return a URL with scheme file://, was '
          '"$url".'));
    }

    return _filesystemImporter.canonicalize(resultUrl);
  }

  ImporterResult? load(Uri url) => _filesystemImporter.load(url);

  DateTime modificationTime(Uri url) =>
      _filesystemImporter.modificationTime(url);

  bool couldCanonicalize(Uri url, Uri canonicalUrl) =>
      _filesystemImporter.couldCanonicalize(url, canonicalUrl);
}
