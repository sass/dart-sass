// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass_embedded/src/embedded_sass.pb.dart';

import 'embedded_process.dart';

/// Returns a [InboundMessage] that compiles the given plain CSS
/// string.
InboundMessage compileString(String css) => InboundMessage()
  ..compileRequest = (InboundMessage_CompileRequest()
    ..string = (InboundMessage_CompileRequest_StringInput()..source = css));

/// Asserts that [process] emits a [ProtocolError] parse error with the given
/// [message] on its protobuf stream and prints a notice on stderr.
Future<void> expectParseError(EmbeddedProcess process, message) async {
  await expectLater(process.outbound,
      emits(isProtocolError(-1, ProtocolError_ErrorType.PARSE, message)));
  await expectLater(process.stderr, emits("Host caused parse error: $message"));
}

/// Asserts that an [OutboundMessage] is a [ProtocolError] with the given [id],
/// [type], and optionally [message].
Matcher isProtocolError(int id, ProtocolError_ErrorType type, [message]) =>
    predicate((value) {
      expect(value, isA<OutboundMessage>());
      var outboundMessage = value as OutboundMessage;
      expect(outboundMessage.hasError(), isTrue,
          reason: "Expected $message to be a ProtocolError");
      expect(outboundMessage.error.id, equals(id));
      expect(outboundMessage.error.type, equals(type));
      if (message != null) expect(outboundMessage.error.message, message);
      return true;
    });

/// Asserts that [message] is an [OutboundMessage] with a [CompileResponse] and
/// returns it.
OutboundMessage_CompileResponse getCompileResponse(value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasCompileResponse(), isTrue,
      reason: "Expected $message to have a CompileResponse");
  return message.compileResponse;
}

/// Asserts that an [OutboundMessage] is a [CompileResponse] with CSS that
/// matches [css].
///
/// If [css] is a [String], this automatically wraps it in
/// [equalsIgnoringWhitespace].
Matcher isSuccess(css) => predicate((value) {
      var response = getCompileResponse(value);
      expect(response.hasSuccess(), isTrue,
          reason: "Expected $response to be successful");
      expect(response.success.css,
          css is String ? equalsIgnoringWhitespace(css) : css);
      return true;
    });
