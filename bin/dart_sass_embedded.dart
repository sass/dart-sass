// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:sass/sass.dart' as sass;
import 'package:source_maps/source_maps.dart' as source_maps;
import 'package:stream_channel/stream_channel.dart';

import 'package:sass_embedded/src/dispatcher.dart';
import 'package:sass_embedded/src/embedded_sass.pb.dart';
import 'package:sass_embedded/src/logger.dart';
import 'package:sass_embedded/src/util/length_delimited_transformer.dart';
import 'package:sass_embedded/src/utils.dart';

void main(List<String> args) {
  if (args.isNotEmpty) {
    stderr.writeln(
        "This executable is not intended to be executed with arguments.\n"
        "See https://github.com/sass/embedded-protocol#readme for details.");
    // USAGE error from https://bit.ly/2poTt90
    exitCode = 64;
    return;
  }

  var dispatcher = Dispatcher(
      StreamChannel.withGuarantees(stdin, stdout, allowSinkErrors: false)
          .transform(lengthDelimited));

  dispatcher.listen((request) {
    var style =
        request.style == InboundMessage_CompileRequest_OutputStyle.COMPRESSED
            ? sass.OutputStyle.compressed
            : sass.OutputStyle.expanded;
    var logger = Logger(dispatcher, request.id);

    try {
      String result;
      source_maps.SingleMapping sourceMap;
      var sourceMapCallback = request.sourceMap
          ? (source_maps.SingleMapping map) => sourceMap = map
          : null;
      switch (request.whichInput()) {
        case InboundMessage_CompileRequest_Input.string:
          var input = request.string;
          result = sass.compileString(input.source,
              logger: logger,
              syntax: _syntaxToSyntax(input.syntax),
              style: style,
              url: input.url.isEmpty ? null : input.url,
              sourceMap: sourceMapCallback);
          break;

        case InboundMessage_CompileRequest_Input.path:
          try {
            result = sass.compile(request.path,
                logger: logger, style: style, sourceMap: sourceMapCallback);
          } on FileSystemException catch (error) {
            return OutboundMessage_CompileResponse()
              ..failure = (OutboundMessage_CompileResponse_CompileFailure()
                ..message = error.path == null
                    ? error.message
                    : "${error.message}: ${error.path}");
          }
          break;

        case InboundMessage_CompileRequest_Input.notSet:
          throw mandatoryError("CompileRequest.input");
      }

      var success = OutboundMessage_CompileResponse_CompileSuccess()
        ..css = result;
      if (sourceMap != null) {
        success.sourceMap = json.encode(sourceMap.toJson());
      }
      return OutboundMessage_CompileResponse()..success = success;
    } on sass.SassException catch (error) {
      return OutboundMessage_CompileResponse()
        ..failure = (OutboundMessage_CompileResponse_CompileFailure()
          ..message = error.message
          ..span = protofySpan(error.span)
          ..stackTrace = error.trace.toString());
    }
  });
}

/// Converts a protocol buffer syntax enum into a Sass API syntax enum.
sass.Syntax _syntaxToSyntax(InboundMessage_Syntax syntax) {
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
