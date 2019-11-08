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
import 'package:sass_embedded/src/importer.dart';
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

  dispatcher.listen((request) async {
    // Wait a single microtask tick so that we're running in a separate
    // microtask from the initial request dispatch. Otherwise, [waitFor] will
    // deadlock the event loop fiber that would otherwise be checking stdin for
    // new input.
    await Future.value();

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

      var importers = request.importers.map((importer) {
        switch (importer.whichImporter()) {
          case InboundMessage_CompileRequest_Importer_Importer.path:
            return sass.FilesystemImporter(importer.path);

          case InboundMessage_CompileRequest_Importer_Importer.importerId:
            return Importer(dispatcher, request.id, importer.importerId);

          case InboundMessage_CompileRequest_Importer_Importer.notSet:
            throw mandatoryError("Importer.importer");

          default:
            throw "Unknown Importer.importer $importer.";
        }
      });

      switch (request.whichInput()) {
        case InboundMessage_CompileRequest_Input.string:
          var input = request.string;
          result = sass.compileString(input.source,
              logger: logger,
              importers: importers,
              syntax: syntaxToSyntax(input.syntax),
              style: style,
              url: input.url.isEmpty ? null : input.url,
              sourceMap: sourceMapCallback);
          break;

        case InboundMessage_CompileRequest_Input.path:
          try {
            result = sass.compile(request.path,
                logger: logger,
                importers: importers,
                style: style,
                sourceMap: sourceMapCallback);
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
