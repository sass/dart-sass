// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../embedded_sass.pb.dart';

extension InboundMessageExtensions on InboundMessage {
  /// Returns the ID of this message, regardless of its type.
  ///
  /// Returns null if [message] doesn't have an id field.
  int? get id => switch (whichMessage()) {
        InboundMessage_Message.versionRequest => versionRequest.id,
        InboundMessage_Message.canonicalizeResponse => canonicalizeResponse.id,
        InboundMessage_Message.importResponse => importResponse.id,
        InboundMessage_Message.fileImportResponse => fileImportResponse.id,
        InboundMessage_Message.functionCallResponse => functionCallResponse.id,
        _ => null
      };
}

extension OutboundMessageExtensions on OutboundMessage {
  /// Returns the outbound ID of this message, regardless of its type.
  ///
  /// Throws an [ArgumentError] if [message] doesn't have an id field.
  int get id => switch (whichMessage()) {
        OutboundMessage_Message.compileResponse => compileResponse.id,
        OutboundMessage_Message.canonicalizeRequest => canonicalizeRequest.id,
        OutboundMessage_Message.importRequest => importRequest.id,
        OutboundMessage_Message.fileImportRequest => fileImportRequest.id,
        OutboundMessage_Message.functionCallRequest => functionCallRequest.id,
        OutboundMessage_Message.versionResponse => versionResponse.id,
        _ => throw ArgumentError("Unknown message type: ${toDebugString()}")
      };

  /// Sets the outbound ID of this message, regardless of its type.
  ///
  /// Throws an [ArgumentError] if [message] doesn't have an id field.
  set id(int id) {
    switch (whichMessage()) {
      case OutboundMessage_Message.compileResponse:
        compileResponse.id = id;
      case OutboundMessage_Message.canonicalizeRequest:
        canonicalizeRequest.id = id;
      case OutboundMessage_Message.importRequest:
        importRequest.id = id;
      case OutboundMessage_Message.fileImportRequest:
        fileImportRequest.id = id;
      case OutboundMessage_Message.functionCallRequest:
        functionCallRequest.id = id;
      case OutboundMessage_Message.versionResponse:
        versionResponse.id = id;
      default:
        throw ArgumentError("Unknown message type: ${toDebugString()}");
    }
  }
}
