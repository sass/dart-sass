// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:cli';
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
import 'package:sass_embedded/src/value.dart';

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
        }

        // dart-lang/sdk#38790
        throw "Unknown Importer.importer $importer.";
      });

      var functions = request.globalFunctions
          .map((signature) => _hostCallable(dispatcher, request.id, signature));

      switch (request.whichInput()) {
        case InboundMessage_CompileRequest_Input.string:
          var input = request.string;
          result = sass.compileString(input.source,
              logger: logger,
              importers: importers,
              functions: functions,
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
                functions: functions,
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

/// Returns a Sass callable that invokes a function defined on the host with the
/// given [signature].
///
/// Throws a [ProtocolError] if [signature] is invalid.
sass.Callable _hostCallable(
    Dispatcher dispatcher, int compilationId, String signature) {
  var openParen = signature.indexOf('(');
  if (openParen == -1) {
    throw paramsError(
        'CompileRequest.global_functions: "$signature" is missing "("');
  }

  if (!signature.endsWith(")")) {
    throw paramsError(
        'CompileRequest.global_functions: "$signature" doesn\'t end with '
        '")"');
  }

  var name = signature.substring(0, openParen);
  try {
    return sass.Callable(
        name, signature.substring(openParen + 1, signature.length - 1),
        (arguments) {
      var request = OutboundMessage_FunctionCallRequest()
        ..compilationId = compilationId
        ..name = name
        ..arguments.addAll(arguments.map(protofyValue));

      var response = waitFor(dispatcher.sendFunctionCallRequest(request));
      try {
        switch (response.whichResult()) {
          case InboundMessage_FunctionCallResponse_Result.success:
            return deprotofyValue(response.success);

          case InboundMessage_FunctionCallResponse_Result.error:
            throw response.error;

          case InboundMessage_FunctionCallResponse_Result.notSet:
            throw mandatoryError('FunctionCallResponse.result');
        }

        // dart-lang/sdk#38790
        throw "Unknown FunctionCallResponse.result $response.";
      } on ProtocolError catch (error) {
        error.id = -1;
        stderr.writeln("Host caused ${error.type.name.toLowerCase()} error: "
            "${error.message}");
        dispatcher.sendError(error);
        throw error.message;
      }
    });
  } on sass.SassException catch (error) {
    throw paramsError('CompileRequest.global_functions: $error');
  }
}
