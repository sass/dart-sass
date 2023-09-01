// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../importer.dart';
import '../dispatcher.dart';
import '../embedded_sass.pb.dart' hide SourceSpan;
import '../utils.dart';
import 'base.dart';

/// An importer that asks the host to resolve imports.
final class HostImporter extends ImporterBase {
  /// The host-provided ID of the importer to invoke.
  final int _importerId;

  HostImporter(Dispatcher dispatcher, this._importerId) : super(dispatcher);

  Uri? canonicalize(Uri url) {
    var response =
        dispatcher.sendCanonicalizeRequest(OutboundMessage_CanonicalizeRequest()
          ..importerId = _importerId
          ..url = url.toString()
          ..fromImport = fromImport);

    return switch (response.whichResult()) {
      InboundMessage_CanonicalizeResponse_Result.url =>
        parseAbsoluteUrl("The importer", response.url),
      InboundMessage_CanonicalizeResponse_Result.error => throw response.error,
      InboundMessage_CanonicalizeResponse_Result.notSet => null
    };
  }

  ImporterResult? load(Uri url) {
    var response = dispatcher.sendImportRequest(OutboundMessage_ImportRequest()
      ..importerId = _importerId
      ..url = url.toString());

    return switch (response.whichResult()) {
      InboundMessage_ImportResponse_Result.success => ImporterResult(
          response.success.contents,
          sourceMapUrl: response.success.sourceMapUrl.isEmpty
              ? null
              : parseAbsoluteUrl("The importer", response.success.sourceMapUrl),
          syntax: syntaxToSyntax(response.success.syntax)),
      InboundMessage_ImportResponse_Result.error => throw response.error,
      InboundMessage_ImportResponse_Result.notSet => null
    };
  }

  String toString() => "HostImporter";
}
