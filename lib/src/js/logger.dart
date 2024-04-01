// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:source_span/source_span.dart';

import 'deprecations.dart';

@JS()
@anonymous
class JSLogger {
  external void Function(String message, WarnOptions options)? get warn;
  external void Function(String message, DebugOptions options)? get debug;

  external factory JSLogger(
      {void Function(String message, WarnOptions options)? warn,
      void Function(String message, DebugOptions options)? debug});
}

@JS()
@anonymous
class WarnOptions {
  external bool get deprecation;
  external Deprecation? get deprecationType;
  external SourceSpan? get span;
  external String? get stack;

  external factory WarnOptions(
      {required bool deprecation,
      Deprecation? deprecationType,
      SourceSpan? span,
      String? stack});
}

@JS()
@anonymous
class DebugOptions {
  external SourceSpan get span;

  external factory DebugOptions({required SourceSpan span});
}
