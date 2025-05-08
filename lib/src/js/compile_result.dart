// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
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
    var sourceMap = this.sourceMap?.toJson(
          includeSourceContents: includeSourceContents,
        );
    if (sourceMap is Map<String, dynamic> &&
        !sourceMap.containsKey('sources')) {
      // Dart's source map library can omit the sources key, but JS's type
      // declaration doesn't allow that.
      sourceMap['sources'] = <String>[];
    }

    // This has to be typed as `<JSAny?>` and cast to work around
    // dart-lang/sdk#61350
    var loadedUrls = <JSAny?>[for (var url in this.loadedUrls) url.toJS].toJS
        as JSArray<URL>;
    return sourceMap == null
        // The JS API tests expects *no* source map here, not a null source map.
        ? JSCompileResult(css: css, loadedUrls: loadedUrls)
        : JSCompileResult(
            css: css,
            loadedUrls: loadedUrls,
            sourceMap: sourceMap.jsify() as JSObject,
          );
  }
}
