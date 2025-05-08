// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:js_interop';

import 'package:cli_pkg/js.dart';
import 'package:js_core/js_core.dart';
import 'package:web/web.dart';

import '../../js/hybrid/canonicalize_context.dart';
import '../../js/utils.dart';
import '../async.dart';
import '../canonicalize_context.dart';
import '../filesystem.dart';
import '../result.dart';
import '../utils.dart';

/// A wrapper for a potentially-asynchronous JS API file importer that exposes
/// it as a Dart [AsyncImporter].
final class JSToDartAsyncFileImporter extends AsyncImporter {
  /// The wrapped `findFileUrl` function.
  final JSAny? Function(String, JSCanonicalizeContext) _findFileUrl;

  JSToDartAsyncFileImporter(this._findFileUrl);

  FutureOr<Uri?> canonicalize(Uri url) async {
    if (url.scheme == 'file') return FilesystemImporter.cwd.canonicalize(url);

    var result = await wrapJSExceptions(
      () => _findFileUrl(url.toString(), canonicalizeContext.toJS),
    ).toDartFutureOr;
    if (result == null) return null;

    var resultUrl = result.asA<URL>()?.toDart;
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
