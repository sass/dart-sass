// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/sass.dart' as sass;
import 'package:source_span/source_span.dart';

import 'embedded_sass.pb.dart' as proto;
import 'embedded_sass.pb.dart' hide SourceSpan;

/// Returns a [ProtocolError] indicating that a mandatory field with the given
/// [fieldName] was missing.
ProtocolError mandatoryError(String fieldName) =>
    paramsError("Missing mandatory field $fieldName");

/// Returns a [ProtocolError] indicating that the parameters for an inbound
/// message were invalid.
ProtocolError paramsError(String message) => ProtocolError()
  // Set the ID to -1 by default, because that's the required value for errors
  // that aren't associated with a specific inbound request ID. This will be
  // overwritten by the dispatcher if a request ID is available.
  ..id = -1
  ..type = ProtocolError_ErrorType.PARAMS
  ..message = message;

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

/// Converts a protocol buffer syntax enum into a Sass API syntax enum.
sass.Syntax syntaxToSyntax(InboundMessage_Syntax syntax) {
  switch (syntax) {
    case InboundMessage_Syntax.SCSS:
      return sass.Syntax.scss;
    case InboundMessage_Syntax.INDENTED:
      return sass.Syntax.sass;
    case InboundMessage_Syntax.CSS:
      return sass.Syntax.css;
    default:
      throw "Unknown syntax $syntax.";
  }
}
