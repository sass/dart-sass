// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:web/web.dart';

import '../compile_result.dart';

extension type JSCompileResult._(JSObject _) implements JSObject {
  external String get css;
  external JSObject? get sourceMap;
  external JSArray<URL> get loadedUrls;

  external JSCompileResult({
    required String css,
    JSObject? sourceMap,
    required JSArray<URL> loadedUrls,
  });
}

extension CompileResultToJS on CompileResult {
  JSCompileResult toJS({required bool includeSourceContents}) {
    var sourceMap = sourceMap?.toJson(
      includeSourceContents: includeSourceContents,
    );
    if (sourceMap is Map<String, dynamic> &&
        !sourceMap.containsKey('sources')) {
      // Dart's source map library can omit the sources key, but JS's type
      // declaration doesn't allow that.
      sourceMap['sources'] = <String>[];
    }

    var loadedUrls = result.loadedUrls.map((url) => url.toJS).toJSCopy;
    return sourceMap == null
        // The JS API tests expects *no* source map here, not a null source map.
        ? JSCompileResult(css: result.css, loadedUrls: loadedUrls)
        : JSCompileResult(
            css: result.css,
            loadedUrls: loadedUrls,
            sourceMap: jsify(sourceMap),
          );
  }
}
