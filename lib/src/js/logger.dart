// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;

import '../deprecation.dart';
import '../js/hybrid/file_span.dart';
import '../logger.dart';
import 'deprecation.dart';

@anonymous
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

@anonymous
extension type WarnOptions._(JSObject _) implements JSObject {
  external bool get deprecation;
  external JSDeprecation? get deprecationType;
  external JSFileSpan? get span;
  external String? get stack;

  external factory WarnOptions({
    required bool deprecation,
    JSDeprecation? deprecationType,
    JSFileSpan? span,
    String? stack,
  });
}

@anonymous
extension type DebugOptions._(JSObject _) implements JSObject {
  external JSFileSpan get span;

  external factory DebugOptions({required JSFileSpan span});
}
