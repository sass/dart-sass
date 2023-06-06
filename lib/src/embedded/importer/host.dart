// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore: deprecated_member_use
import 'dart:cli';

import '../../importer.dart';
import '../dispatcher.dart';
import '../embedded_sass.pb.dart' hide SourceSpan;
import '../utils.dart';
import 'base.dart';

/// An importer that asks the host to resolve imports.
class HostImporter extends ImporterBase {
  /// The host-provided ID of the importer to invoke.
  final int _importerId;

  HostImporter(Dispatcher dispatcher, this._importerId) : super(dispatcher);

  Uri? canonicalize(Uri url) {
    // ignore: deprecated_member_use
    return waitFor(() async {
      var response = await dispatcher
          .sendCanonicalizeRequest(OutboundMessage_CanonicalizeRequest()
            ..importerId = _importerId
            ..url = url.toString()
            ..fromImport = fromImport);

      switch (response.whichResult()) {
        case InboundMessage_CanonicalizeResponse_Result.url:
          return parseAbsoluteUrl("The importer", response.url);

        case InboundMessage_CanonicalizeResponse_Result.error:
          throw response.error;

        case InboundMessage_CanonicalizeResponse_Result.notSet:
          return null;
      }
    }());
  }

  ImporterResult? load(Uri url) {
    // ignore: deprecated_member_use
    return waitFor(() async {
      var response =
          await dispatcher.sendImportRequest(OutboundMessage_ImportRequest()
            ..importerId = _importerId
            ..url = url.toString());

      switch (response.whichResult()) {
        case InboundMessage_ImportResponse_Result.success:
          return ImporterResult(response.success.contents,
              sourceMapUrl: response.success.sourceMapUrl.isEmpty
                  ? null
                  : parseAbsoluteUrl(
                      "The importer", response.success.sourceMapUrl),
              syntax: syntaxToSyntax(response.success.syntax));

        case InboundMessage_ImportResponse_Result.error:
          throw response.error;

        case InboundMessage_ImportResponse_Result.notSet:
          return null;
      }
    }());
  }

  String toString() => "HostImporter";
}
