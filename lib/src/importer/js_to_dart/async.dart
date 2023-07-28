// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';

import '../../js/importer.dart';
import '../../js/url.dart';
import '../../js/utils.dart';
import '../../util/nullable.dart';
import '../async.dart';
import '../result.dart';

/// A wrapper for a potentially-asynchronous JS API importer that exposes it as
/// a Dart [AsyncImporter].
final class JSToDartAsyncImporter extends AsyncImporter {
  /// The wrapped canonicalize function.
  final Object? Function(String, CanonicalizeOptions) _canonicalize;

  /// The wrapped load function.
  final Object? Function(JSUrl) _load;

  JSToDartAsyncImporter(this._canonicalize, this._load);

  FutureOr<Uri?> canonicalize(Uri url) async {
    var result = _canonicalize(
        url.toString(), CanonicalizeOptions(fromImport: fromImport));
    if (isPromise(result)) result = await promiseToFuture(result as Promise);
    if (result == null) return null;

    if (isJSUrl(result)) return jsToDartUrl(result as JSUrl);

    jsThrow(JsError("The canonicalize() method must return a URL."));
  }

  FutureOr<ImporterResult?> load(Uri url) async {
    var result = _load(dartToJSUrl(url));
    if (isPromise(result)) result = await promiseToFuture(result as Promise);
    if (result == null) return null;

    result as NodeImporterResult;
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
}
