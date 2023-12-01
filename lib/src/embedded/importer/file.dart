// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../importer.dart';
import '../compilation_dispatcher.dart';
import '../embedded_sass.pb.dart' hide SourceSpan;
import 'base.dart';

/// An importer that asks the host to resolve imports in a simplified,
/// file-system-centric way.
final class FileImporter extends ImporterBase {
  /// The host-provided ID of the importer to invoke.
  final int _importerId;

  FileImporter(CompilationDispatcher dispatcher, this._importerId)
      : super(dispatcher);

  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') return FilesystemImporter.cwd.canonicalize(url);

    var request = OutboundMessage_FileImportRequest()
      ..importerId = _importerId
      ..url = url.toString()
      ..fromImport = fromImport;
    if (containingUrl case var containingUrl?) {
      request.containingUrl = containingUrl.toString();
    }
    var response = dispatcher.sendFileImportRequest(request);

    switch (response.whichResult()) {
      case InboundMessage_FileImportResponse_Result.fileUrl:
        var url = parseAbsoluteUrl("The file importer", response.fileUrl);
        if (url.scheme != 'file') {
          throw 'The file importer must return a file: URL, was "$url"';
        }

        return FilesystemImporter.cwd.canonicalize(url);

      case InboundMessage_FileImportResponse_Result.error:
        throw response.error;

      case InboundMessage_FileImportResponse_Result.notSet:
        return null;
    }
  }

  ImporterResult? load(Uri url) => FilesystemImporter.cwd.load(url);

  bool isNonCanonicalScheme(String scheme) => scheme != 'file';

  String toString() => "FileImporter";
}
