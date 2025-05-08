// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:web/web.dart';

import '../../js/hybrid/canonicalize_context.dart';
import '../../js/importer.dart';
import '../../js/utils.dart';
import '../async.dart';
import '../canonicalize_context.dart';
import '../result.dart';
import 'utils.dart';

/// A wrapper for a potentially-asynchronous JS API importer that exposes it as
/// a Dart [AsyncImporter].
final class JSToDartAsyncImporter extends AsyncImporter {
  /// The wrapped canonicalize function.
  final JSAny? Function(String, UnsafeDartWrapper<CanonicalizeContext>)
      _canonicalize;

  /// The wrapped load function.
  final JSAny? Function(URL) _load;

  /// The set of URL schemes that this importer promises never to return from
  /// [canonicalize].
  final Set<String> _nonCanonicalSchemes;

  JSToDartAsyncImporter(
    this._canonicalize,
    this._load,
    Iterable<String>? nonCanonicalSchemes,
  ) : _nonCanonicalSchemes = nonCanonicalSchemes == null
            ? const {}
            : Set.unmodifiable(nonCanonicalSchemes) {
    _nonCanonicalSchemes.forEach(validateUrlScheme);
  }

  FutureOr<Uri?> canonicalize(Uri url) async {
    var result = await _canonicalize(url.toString(), canonicalizeContext.toJS)
        .toDartFutureOr;
    if (result == null) return null;
    if (result.isA<URL>()) return (result as URL).toDart;

    JSError.throwLikeJS(
        JSError("The canonicalize() method must return a URL."));
  }

  FutureOr<ImporterResult?> load(Uri url) async {
    var result = (await _load(url.toJS).toDartFutureOr) as JSImporterResult?;
    if (result == null) return null;

    var contents = result.contents;
    var syntax = result.syntax;
    if (contents == null || syntax == null) {
      JSError.throwLikeJS(
        JSError(
          "The load() function must return an object with contents "
          "and syntax fields.",
        ),
      );
    }

    var contentsString =
        contents.isA<JSString>() ? (contents as JSString).toDart : null;
    if (contentsString == null) {
      JSError.throwLikeJS(
        ArgumentError.value(
          contents,
          'contents',
          'must be a string but was: ${contents.jsTypeName}',
        ).toJS,
      );
    }

    return ImporterResult(
      contentsString,
      syntax: parseSyntax(syntax),
      sourceMapUrl: result.sourceMapUrl?.toDart,
    );
  }

  bool isNonCanonicalScheme(String scheme) =>
      _nonCanonicalSchemes.contains(scheme);
}
