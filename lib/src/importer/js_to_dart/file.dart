// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:web/web.dart';

import '../../importer.dart';
import '../../js/hybrid/canonicalize_context.dart';
import '../canonicalize_context.dart';
import '../utils.dart';

/// A wrapper for a potentially-asynchronous JS API file importer that exposes
/// it as a Dart [AsyncImporter].
final class JSToDartFileImporter extends Importer {
  /// The wrapped `findFileUrl` function.
  final JSAny? Function(String, UnsafeDartWrapper<CanonicalizeContext>)
      _findFileUrl;

  JSToDartFileImporter(this._findFileUrl);

  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') return FilesystemImporter.cwd.canonicalize(url);

    var result = _findFileUrl(url.toString(), canonicalizeContext.toJS);
    if (result == null) return null;
    if (result.isA<JSPromise>()) {
      JSError.throwLikeJS(
        JSError(
          "The findFileUrl() function can't return a Promise for synchron "
          "compile functions.",
        ),
      );
    }

    var resultUrl = result.isA<URL>() ? (result as URL).toDart : null;
    if (resultUrl == null) {
      JSError.throwLikeJS(
          JSError("The findFileUrl() method must return a URL."));
    } else if (resultUrl.scheme != 'file') {
      JSError.throwLikeJS(
        JSError(
          'The findFileUrl() must return a URL with scheme file://, was '
          '"$url".',
        ),
      );
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
