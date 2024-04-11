// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:cli_pkg/js.dart';
import 'package:node_interop/js.dart';

import '../../importer.dart';
import '../../js/importer.dart';
import '../../js/url.dart';
import '../../js/utils.dart';
import '../../util/nullable.dart';
import 'utils.dart';

/// A wrapper for a synchronous JS API importer that exposes it as a Dart
/// [Importer].
final class JSToDartImporter extends Importer {
  /// The wrapped canonicalize function.
  final Object? Function(String, JSCanonicalizeContext) _canonicalize;

  /// The wrapped load function.
  final Object? Function(JSUrl) _load;

  /// The set of URL schemes that this importer promises never to return from
  /// [canonicalize].
  final Set<String> _nonCanonicalSchemes;

  JSToDartImporter(
      this._canonicalize, this._load, Iterable<String>? nonCanonicalSchemes)
      : _nonCanonicalSchemes = nonCanonicalSchemes == null
            ? const {}
            : Set.unmodifiable(nonCanonicalSchemes) {
    _nonCanonicalSchemes.forEach(validateUrlScheme);
  }

  Uri? canonicalize(Uri url) {
    var result = wrapJSExceptions(() => _canonicalize(
        url.toString(), dartToJSCanonicalizeContext(canonicalizeContext)));
    if (result == null) return null;
    if (isJSUrl(result)) return jsToDartUrl(result as JSUrl);

    if (isPromise(result)) {
      jsThrow(JsError(
          "The canonicalize() function can't return a Promise for synchronous "
          "compile functions."));
    } else {
      jsThrow(JsError("The canonicalize() method must return a URL."));
    }
  }

  ImporterResult? load(Uri url) {
    var result = wrapJSExceptions(() => _load(dartToJSUrl(url)));
    if (result == null) return null;

    if (isPromise(result)) {
      jsThrow(JsError(
          "The load() function can't return a Promise for synchronous compile "
          "functions."));
    }

    result as JSImporterResult;
    var contents = result.contents;
    if (!isJsString(contents)) {
      jsThrow(ArgumentError.value(contents, 'contents',
          'must be a string but was: ${jsType(contents)}'));
    }

    var syntax = result.syntax;
    if (contents == null || syntax == null) {
      jsThrow(JsError("The load() function must return an object with contents "
          "and syntax fields."));
    }

    return ImporterResult(contents,
        syntax: parseSyntax(syntax),
        sourceMapUrl: result.sourceMapUrl.andThen(jsToDartUrl));
  }

  bool isNonCanonicalScheme(String scheme) =>
      _nonCanonicalSchemes.contains(scheme);
}
