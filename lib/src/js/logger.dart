// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';
import 'package:source_span/source_span.dart';

import 'deprecation.dart';

extension type JSLogger._(JSObject _) implements JSObject {
  @JS('warn')
  external JSFunction? get _nullableWarn;
  @JS('warn')
  external void _warn(String message, WarnOptions options);
  void Function(String message, WarnOptions options)? get warn =>
      _nullableWarn == null
          ? null
          : (message, options) => _warn(message, options);

  @JS('debug')
  external JSFunction? get _nullableDebug;
  @JS('debug')
  external void _debug(String message, DebugOptions options);
  void Function(String message, DebugOptions options)? get debug =>
      _nullableDebug == null
          ? null
          : (message, options) => _debug(message, options);

  external JSLogger({JSFunction? warn, JSFunction? debug});
}

extension type WarnOptions._(JSObject _) implements JSObject {
  external bool get deprecation;
  external JSDeprecation? get deprecationType;
  external UnsafeDartWrapper<FileSpan>? get span;
  external String? get stack;

  external WarnOptions({
    required bool deprecation,
    JSDeprecation? deprecationType,
    UnsafeDartWrapper<FileSpan>? span,
    String? stack,
  });
}

extension type DebugOptions._(JSObject _) implements JSObject {
  external UnsafeDartWrapper<SourceSpan> get span;

  external DebugOptions({required UnsafeDartWrapper<SourceSpan> span});
}
