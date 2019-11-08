// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:cli';

import 'package:meta/meta.dart';
import 'package:sass/sass.dart' as sass;

import 'dispatcher.dart';
import 'embedded_sass.pb.dart' hide SourceSpan;
import 'utils.dart';

/// An importer that asks the host to resolve imports.
class Importer extends sass.Importer {
  /// The [Dispatcher] to which to send requests.
  final Dispatcher _dispatcher;

  /// The ID of the compilation in which this importer is used.
  final int _compilationId;

  /// The host-provided ID of the importer to invoke.
  final int _importerId;

  Importer(this._dispatcher, this._compilationId, this._importerId);

  Uri canonicalize(Uri url) {
    return waitFor(() async {
      var response = await _dispatcher
          .sendCanonicalizeRequest(OutboundMessage_CanonicalizeRequest()
            ..compilationId = _compilationId
            ..importerId = _importerId
            ..url = url.toString());

      switch (response.whichResult()) {
        case InboundMessage_CanonicalizeResponse_Result.url:
          return _parseAbsoluteUrl("CanonicalizeResponse.url", response.url);

        case InboundMessage_CanonicalizeResponse_Result.file:
          throw "CanonicalizeResponse.file is not yet supported";

        case InboundMessage_CanonicalizeResponse_Result.error:
          throw response.error;

        case InboundMessage_CanonicalizeResponse_Result.notSet:
          return null;

        default:
          throw "Unknown CanonicalizeResponse.result $response.";
      }
    }());
  }

  sass.ImporterResult load(Uri url) {
    return waitFor(() async {
      var response =
          await _dispatcher.sendImportRequest(OutboundMessage_ImportRequest()
            ..compilationId = _compilationId
            ..importerId = _importerId
            ..url = url.toString());

      switch (response.whichResult()) {
        case InboundMessage_ImportResponse_Result.success:
          return sass.ImporterResult(response.success.contents,
              sourceMapUrl: response.success.sourceMapUrl.isEmpty
                  ? null
                  : _parseAbsoluteUrl("ImportResponse.success.source_map_url",
                      response.success.sourceMapUrl),
              syntax: syntaxToSyntax(response.success.syntax));

        case InboundMessage_ImportResponse_Result.error:
          throw response.error;

        case InboundMessage_ImportResponse_Result.notSet:
          _sendAndThrow(mandatoryError("ImportResponse.result"));
          break; // dart-lang/sdk#34048

        default:
          throw "Unknown ImporterResponse.result $response.";
      }
    }());
  }

  /// Parses [url] as a [Uri] and throws an error if it's invalid or relative
  /// (including root-relative).
  ///
  /// The [field] name is used in the error message if one is thrown.
  Uri _parseAbsoluteUrl(String field, String url) {
    Uri parsedUrl;
    try {
      parsedUrl = Uri.parse(url);
    } on FormatException catch (error) {
      _sendAndThrow(paramsError("$field is invalid: $error"));
    }

    if (parsedUrl.scheme.isNotEmpty) return parsedUrl;
    _sendAndThrow(paramsError('$field must be absolute, was "$parsedUrl"'));
  }

  /// Sends [error] to the remote endpoint, and also throws it so that the Sass
  /// compilation fails.
  @alwaysThrows
  void _sendAndThrow(ProtocolError error) {
    _dispatcher.sendError(error);
    throw "Protocol error: ${error.message}";
  }

  String toString() => "HostImporter";
}
