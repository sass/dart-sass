// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'embedded_sass.pb.dart' as proto;
import 'embedded_sass.pb.dart' hide SourceSpan;

/// Returns a [ProtocolError] indicating that a mandatory field with the givne
/// [fieldName] was missing.
ProtocolError mandatoryError(String fieldName) => ProtocolError()
  ..type = ProtocolError_ErrorType.PARAMS
  ..message = "Missing mandatory field $fieldName";

/// Converts a Dart source span to a protocol buffer source span.
proto.SourceSpan protofySpan(SourceSpan span) {
  var protoSpan = proto.SourceSpan()
    ..text = span.text
    ..start = _protofyLocation(span.start)
    ..end = _protofyLocation(span.end)
    ..url = span.sourceUrl?.toString() ?? "";
  if (span is SourceSpanWithContext) protoSpan.context = span.context;
  return protoSpan;
}

/// Converts a Dart source location to a protocol buffer source location.
SourceSpan_SourceLocation _protofyLocation(SourceLocation location) =>
    SourceSpan_SourceLocation()
      ..offset = location.offset
      ..line = location.line
      ..column = location.column;
