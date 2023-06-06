// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';
import 'package:source_span/source_span.dart';
import 'package:term_glyph/term_glyph.dart' as term_glyph;

import '../syntax.dart';
import 'embedded_sass.pb.dart' as proto;
import 'embedded_sass.pb.dart' hide SourceSpan, Syntax;
import 'util/varint_builder.dart';

/// The special ID that indicates an error that's not associated with a specific
/// inbound request ID.
const errorId = 0xffffffff;

/// Returns a [ProtocolError] indicating that a mandatory field with the given
/// [fieldName] was missing.
ProtocolError mandatoryError(String fieldName) =>
    paramsError("Missing mandatory field $fieldName");

/// Returns a [ProtocolError] indicating that the parameters for an inbound
/// message were invalid.
ProtocolError paramsError(String message) => ProtocolError()
  // Set the ID to [errorId] by default. This will be overwritten by the
  // dispatcher if a request ID is available.
  ..id = errorId
  ..type = ProtocolErrorType.PARAMS
  ..message = message;

/// Returns a [ProtocolError] with type `PARSE` and the given [message].
ProtocolError parseError(String message) => ProtocolError()
  ..type = ProtocolErrorType.PARSE
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
Syntax syntaxToSyntax(proto.Syntax syntax) {
  switch (syntax) {
    case proto.Syntax.SCSS:
      return Syntax.scss;
    case proto.Syntax.INDENTED:
      return Syntax.sass;
    case proto.Syntax.CSS:
      return Syntax.css;
    default:
      throw "Unknown syntax $syntax.";
  }
}

/// Returns the result of running [callback] with the global ASCII config set
/// to [ascii].
T withGlyphs<T>(T callback(), {required bool ascii}) {
  var currentConfig = term_glyph.ascii;
  term_glyph.ascii = ascii;
  var result = callback();
  term_glyph.ascii = currentConfig;
  return result;
}

/// Serializes [value] to an unsigned varint.
Uint8List serializeVarint(int value) {
  if (value == 0) return Uint8List.fromList([0]);
  RangeError.checkNotNegative(value);

  // Essentially `(value.bitLength / 7).ceil()`, but without getting floats
  // involved.
  var lengthInBytes = (value.bitLength + 6) ~/ 7;
  var list = Uint8List(lengthInBytes);
  for (var i = 0; i < lengthInBytes; i++) {
    // The highest-order bit indicates whether more bytes are necessary to fully
    // express the number. The lower 7 bits indicate the number's value.
    list[i] = (value > 0x7f ? 0x80 : 0) | (value & 0x7f);
    value >>= 7;
  }
  return list;
}

/// Serializes a compilation ID and protobuf message into a packet buffer as
/// specified in the embedded protocol.
Uint8List serializePacket(int compilationId, GeneratedMessage message) {
  var varint = serializeVarint(compilationId);
  var protobufWriter = CodedBufferWriter();
  message.writeToCodedBufferWriter(protobufWriter);

  var packet = Uint8List(varint.length + protobufWriter.lengthInBytes);
  packet.setAll(0, varint);
  protobufWriter.writeTo(packet, varint.length);
  return packet;
}

/// A [VarintBuilder] that's shared across invocations of [parsePacket] to avoid
/// unnecessary allocations.
final _compilationIdBuilder = VarintBuilder(32, 'compilation ID');

/// Parses a compilation ID and encoded protobuf message from a packet buffer as
/// specified in the embedded protocol.
(int, Uint8List) parsePacket(Uint8List packet) {
  try {
    var i = 0;
    while (true) {
      if (i == packet.length) {
        throw parseError(
            "Invalid compilation ID: continuation bit always set.");
      }

      var compilationId = _compilationIdBuilder.add(packet[i]);
      i++;
      if (compilationId != null) {
        return (compilationId, Uint8List.sublistView(packet, i));
      }
    }
  } finally {
    _compilationIdBuilder.reset();
  }
}
