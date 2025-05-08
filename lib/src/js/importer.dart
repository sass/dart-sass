// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:web/web.dart';

import '../importer/canonicalize_context.dart';

extension type JSImporter._(JSObject _) implements JSObject {
  @JS('canonicalize')
  external JSFunction? get _nullableCanonicalize;
  @JS('canonicalize')
  external JSAny? _canonicalize(
      String url, UnsafeDartWrapper<CanonicalizeContext> context);
  JSAny? Function(String, UnsafeDartWrapper<CanonicalizeContext>)?
      get canonicalize => _nullableCanonicalize == null
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
  external JSAny? _findFileUrl(
      String url, UnsafeDartWrapper<CanonicalizeContext> context);
  JSAny? Function(String, UnsafeDartWrapper<CanonicalizeContext>)?
      get findFileUrl => _nullableFindFileUrl == null
          ? null
          : (url, context) => _findFileUrl(url, context);

  @JS('nonCanonicalScheme')
  external JSAny? get _nonCanonicalScheme;
  List<String>? get nonCanonicalSchemes => switch (_nonCanonicalScheme) {
        JSString scheme => [scheme.toDart],
        JSArray<JSAny?> schemes => schemes.toDart.cast<String>(),
        null => null,
        var schemes => JSError.throwLikeJS(
            JSError(
              'nonCanonicalScheme must be a string or list of strings, was '
              '"$schemes" (${schemes.jsTypeName})',
            ),
          ),
      };
}

extension type JSImporterResult._(JSObject _) implements JSObject {
  // This is _expected_ to be a [JSString], but we type it as [JSAny] to allow
  // us to do more explicit type checking and produce better errors.
  external JSAny? get contents;
  external String? get syntax;
  external URL? get sourceMapUrl;
}
