// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:web/web.dart';

import '../../importer.dart';
import '../../js/hybrid/canonicalize_context.dart';
import '../../js/importer.dart';
import '../../js/utils.dart';
import '../canonicalize_context.dart';
import 'utils.dart';

/// A wrapper for a synchronous JS API importer that exposes it as a Dart
/// [Importer].
final class JSToDartImporter extends Importer {
  /// The wrapped canonicalize function.
  final JSAny? Function(String, UnsafeDartWrapper<CanonicalizeContext>)
      _canonicalize;

  /// The wrapped load function.
  final JSAny? Function(URL) _load;

  /// The set of URL schemes that this importer promises never to return from
  /// [canonicalize].
  final Set<String> _nonCanonicalSchemes;

  JSToDartImporter(
    this._canonicalize,
    this._load,
    Iterable<String>? nonCanonicalSchemes,
  ) : _nonCanonicalSchemes = nonCanonicalSchemes == null
            ? const {}
            : Set.unmodifiable(nonCanonicalSchemes) {
    _nonCanonicalSchemes.forEach(validateUrlScheme);
  }

  Uri? canonicalize(Uri url) {
    var result = _canonicalize(url.toString(), canonicalizeContext.toJS);
    if (result == null) return null;
    if (result.isA<URL>()) return (result as URL).toDart;

    if (result.isA<JSPromise>()) {
      JSError.throwLikeJS(
        JSError(
          "The canonicalize() function can't return a Promise for synchronous "
          "compile functions.",
        ),
      );
    } else {
      JSError.throwLikeJS(
          JSError("The canonicalize() method must return a URL."));
    }
  }

  ImporterResult? load(Uri url) {
    var result = _load(url.toJS);
    if (result == null) return null;

    if (result.isA<JSPromise>()) {
      JSError.throwLikeJS(
        JSError(
          "The load() function can't return a Promise for synchronous compile "
          "functions.",
        ),
      );
    }

    result as JSImporterResult;
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
