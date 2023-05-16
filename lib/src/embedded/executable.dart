// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';

import '../../sass.dart';
import 'dispatcher.dart';
import 'embedded_sass.pb.dart' as proto;
import 'embedded_sass.pb.dart' hide OutputStyle;
import 'function_registry.dart';
import 'host_callable.dart';
import 'importer/file.dart';
import 'importer/host.dart';
import 'logger.dart';
import 'util/length_delimited_transformer.dart';
import 'utils.dart';

void main(List<String> args) {
  if (args.isNotEmpty) {
    if (args.first == "--version") {
      var response = Dispatcher.versionResponse();
      response.id = 0;
      stdout.writeln(
          JsonEncoder.withIndent("  ").convert(response.toProto3Json()));
      return;
    }

    stderr.writeln(
        "sass --embedded is not intended to be executed with additional "
        "arguments.\n"
        "See https://github.com/sass/dart-sass#embedded-dart-sass for "
        "details.");
    // USAGE error from https://bit.ly/2poTt90
    exitCode = 64;
    return;
  }

  var dispatcher = Dispatcher(
      StreamChannel.withGuarantees(stdin, stdout, allowSinkErrors: false)
          .transform(lengthDelimited));

  dispatcher.listen((request) async {
    var functions = FunctionRegistry();

    var style = request.style == proto.OutputStyle.COMPRESSED
        ? OutputStyle.compressed
        : OutputStyle.expanded;
    var logger = EmbeddedLogger(dispatcher, request.id,
        color: request.alertColor, ascii: request.alertAscii);

    try {
      var importers = request.importers.map((importer) =>
          _decodeImporter(dispatcher, request, importer) ??
          (throw mandatoryError("Importer.importer")));

      var globalFunctions = request.globalFunctions.map((signature) =>
          hostCallable(dispatcher, functions, request.id, signature));

      late CompileResult result;
      switch (request.whichInput()) {
        case InboundMessage_CompileRequest_Input.string:
          var input = request.string;
          result = compileStringToResult(input.source,
              color: request.alertColor,
              logger: logger,
              importers: importers,
              importer: _decodeImporter(dispatcher, request, input.importer) ??
                  (input.url.startsWith("file:") ? null : Importer.noOp),
              functions: globalFunctions,
              syntax: syntaxToSyntax(input.syntax),
              style: style,
              url: input.url.isEmpty ? null : input.url,
              quietDeps: request.quietDeps,
              verbose: request.verbose,
              sourceMap: request.sourceMap,
              charset: request.charset);
          break;

        case InboundMessage_CompileRequest_Input.path:
          if (request.path.isEmpty) {
            throw mandatoryError("CompileRequest.Input.path");
          }

          try {
            result = compileToResult(request.path,
                color: request.alertColor,
                logger: logger,
                importers: importers,
                functions: globalFunctions,
                style: style,
                quietDeps: request.quietDeps,
                verbose: request.verbose,
                sourceMap: request.sourceMap,
                charset: request.charset);
          } on FileSystemException catch (error) {
            return OutboundMessage_CompileResponse()
              ..failure = (OutboundMessage_CompileResponse_CompileFailure()
                ..message = error.path == null
                    ? error.message
                    : "${error.message}: ${error.path}"
                ..span = (SourceSpan()
                  ..start = SourceSpan_SourceLocation()
                  ..end = SourceSpan_SourceLocation()
                  ..url = p.toUri(request.path).toString()));
          }
          break;

        case InboundMessage_CompileRequest_Input.notSet:
          throw mandatoryError("CompileRequest.input");
      }

      var success = OutboundMessage_CompileResponse_CompileSuccess()
        ..css = result.css
        ..loadedUrls.addAll(result.loadedUrls.map((url) => url.toString()));

      var sourceMap = result.sourceMap;
      if (sourceMap != null) {
        success.sourceMap = json.encode(sourceMap.toJson(
            includeSourceContents: request.sourceMapIncludeSources));
      }
      return OutboundMessage_CompileResponse()..success = success;
    } on SassException catch (error) {
      var formatted = withGlyphs(
          () => error.toString(color: request.alertColor),
          ascii: request.alertAscii);
      return OutboundMessage_CompileResponse()
        ..failure = (OutboundMessage_CompileResponse_CompileFailure()
          ..message = error.message
          ..span = protofySpan(error.span)
          ..stackTrace = error.trace.toString()
          ..formatted = formatted);
    }
  });
}

/// Converts [importer] into a [Importer].
Importer? _decodeImporter(
    Dispatcher dispatcher,
    InboundMessage_CompileRequest request,
    InboundMessage_CompileRequest_Importer importer) {
  switch (importer.whichImporter()) {
    case InboundMessage_CompileRequest_Importer_Importer.path:
      return FilesystemImporter(importer.path);

    case InboundMessage_CompileRequest_Importer_Importer.importerId:
      return HostImporter(dispatcher, request.id, importer.importerId);

    case InboundMessage_CompileRequest_Importer_Importer.fileImporterId:
      return FileImporter(dispatcher, request.id, importer.fileImporterId);

    case InboundMessage_CompileRequest_Importer_Importer.notSet:
      return null;
  }
}
