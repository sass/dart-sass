// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore: deprecated_member_use
import 'dart:cli';

import '../../importer.dart';
import '../dispatcher.dart';
import '../embedded_sass.pb.dart' hide SourceSpan;
import 'base.dart';

/// A filesystem importer to use for most implementation details of
/// [FileImporter].
///
/// This allows us to avoid duplicating logic between the two importers.
final _filesystemImporter = FilesystemImporter('.');

/// An importer that asks the host to resolve imports in a simplified,
/// file-system-centric way.
class FileImporter extends ImporterBase {
  /// The host-provided ID of the importer to invoke.
  final int _importerId;

  FileImporter(Dispatcher dispatcher, this._importerId) : super(dispatcher);

  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') return _filesystemImporter.canonicalize(url);

    // ignore: deprecated_member_use
    return waitFor(() async {
      var response = await dispatcher
          .sendFileImportRequest(OutboundMessage_FileImportRequest()
            ..importerId = _importerId
            ..url = url.toString()
            ..fromImport = fromImport);

      switch (response.whichResult()) {
        case InboundMessage_FileImportResponse_Result.fileUrl:
          var url = parseAbsoluteUrl("The file importer", response.fileUrl);
          if (url.scheme != 'file') {
            throw 'The file importer must return a file: URL, was "$url"';
          }

          return _filesystemImporter.canonicalize(url);

        case InboundMessage_FileImportResponse_Result.error:
          throw response.error;

        case InboundMessage_FileImportResponse_Result.notSet:
          return null;
      }
    }());
  }

  ImporterResult? load(Uri url) => _filesystemImporter.load(url);

  String toString() => "FileImporter";
}
