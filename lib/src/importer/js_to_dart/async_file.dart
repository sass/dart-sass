// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:cli_pkg/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';

import '../../js/importer.dart';
import '../../js/url.dart';
import '../../js/utils.dart';
import '../../util/nullable.dart';
import '../async.dart';
import '../filesystem.dart';
import '../result.dart';
import '../utils.dart';

/// A wrapper for a potentially-asynchronous JS API file importer that exposes
/// it as a Dart [AsyncImporter].
final class JSToDartAsyncFileImporter extends AsyncImporter {
  /// The wrapped `findFileUrl` function.
  final Object? Function(String, CanonicalizeContext) _findFileUrl;

  JSToDartAsyncFileImporter(this._findFileUrl);

  FutureOr<Uri?> canonicalize(Uri url) async {
    if (url.scheme == 'file') return FilesystemImporter.cwd.canonicalize(url);

    var result = wrapJSExceptions(() => _findFileUrl(
        url.toString(),
        CanonicalizeContext(
            fromImport: fromImport,
            containingUrl: containingUrl.andThen(dartToJSUrl))));
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

    return FilesystemImporter.cwd.canonicalize(resultUrl);
  }

  ImporterResult? load(Uri url) => FilesystemImporter.cwd.load(url);

  DateTime modificationTime(Uri url) =>
      FilesystemImporter.cwd.modificationTime(url);

  bool couldCanonicalize(Uri url, Uri canonicalUrl) =>
      FilesystemImporter.cwd.couldCanonicalize(url, canonicalUrl);

  bool isNonCanonicalScheme(String scheme) => scheme != 'file';
}
