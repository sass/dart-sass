// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:cli';

import 'package:sass_api/sass_api.dart' as sass;

import '../dispatcher.dart';
import '../embedded_sass.pb.dart' hide SourceSpan;
import '../utils.dart';
import 'base.dart';

/// An importer that asks the host to resolve imports.
class HostImporter extends ImporterBase {
  /// The ID of the compilation in which this importer is used.
  final int _compilationId;

  /// The host-provided ID of the importer to invoke.
  final int _importerId;

  HostImporter(Dispatcher dispatcher, this._compilationId, this._importerId)
      : super(dispatcher);

  Uri? canonicalize(Uri url) {
    return waitFor(() async {
      var response = await dispatcher
          .sendCanonicalizeRequest(OutboundMessage_CanonicalizeRequest()
            ..compilationId = _compilationId
            ..importerId = _importerId
            ..url = url.toString()
            ..fromImport = fromImport);

      switch (response.whichResult()) {
        case InboundMessage_CanonicalizeResponse_Result.url:
          return parseAbsoluteUrl("CanonicalizeResponse.url", response.url);

        case InboundMessage_CanonicalizeResponse_Result.error:
          throw response.error;

        case InboundMessage_CanonicalizeResponse_Result.notSet:
          return null;
      }
    }());
  }

  sass.ImporterResult load(Uri url) {
    return waitFor(() async {
      var response =
          await dispatcher.sendImportRequest(OutboundMessage_ImportRequest()
            ..compilationId = _compilationId
            ..importerId = _importerId
            ..url = url.toString());

      switch (response.whichResult()) {
        case InboundMessage_ImportResponse_Result.success:
          return sass.ImporterResult(response.success.contents,
              sourceMapUrl: response.success.sourceMapUrl.isEmpty
                  ? null
                  : parseAbsoluteUrl("ImportResponse.success.source_map_url",
                      response.success.sourceMapUrl),
              syntax: syntaxToSyntax(response.success.syntax));

        case InboundMessage_ImportResponse_Result.error:
          throw response.error;

        case InboundMessage_ImportResponse_Result.notSet:
          sendAndThrow(mandatoryError("ImportResponse.result"));
      }
    }());
  }

  String toString() => "HostImporter";
}
