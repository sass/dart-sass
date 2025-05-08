// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import '../importer/canonicalize_context.dart';
import 'url.dart';

@anonymous
extension type JSImporter._(JSObject _) implements JSObject {
  @JS('canonicalize')
  external JSFunction? get _nullableCanonicalize;
  @JS('canonicalize')
  external JSAny? _canonicalize(String url, CanonicalizeContext context);
  JSAny? Function(String, CanonicalizeContext)? get canonicalize =>
      _nullableCanonicalize == null
          ? null
          : (url, context) => _canonicalize(url, context);

  @JS('load')
  external JSFunction? get _nullableLoad;
  @JS('load')
  external JSAny? _load(URL url);
  JSAny? Function(URL)? get load =>
      _nullableLoad == null ? null : (url) => _load(url);

  @JS('findFileUrl')
  external JSFunction? get _nullableFindFileUrl;
  @JS('findFileUrl')
  external JSAny? _findFileUrl(String url, CanonicalizeContext context);
  JSAny? Function(String, CanonicalizeContext)? get findFileUrl =>
      _nullableFindFileUrl == null
          ? null
          : (url, context) => _findFileUrl(url, context);

          @JS('nonCanonicalScheme')
  external JSAny? get _nonCanonicalScheme;
  List<String> get nonCanonicalSchemes =>     switch (_nonCanonicalScheme) {
      JSString scheme => [scheme.toDart],
      JSArray<JSAny?> schemes => schemes.cast<String>(),
      null => null,
      var schemes => JSError.throwLikeJS(
          JSError(
            'nonCanonicalScheme must be a string or list of strings, was '
            '"$schemes" (${schemes.jsTypeName})',
          ),
        ),
    };
}

@anonymous
extension type JSImporterResult._(JSObject _) implements JSObject {
  external String? get contents;
  external String? get syntax;
  external URL? get sourceMapUrl;
}
