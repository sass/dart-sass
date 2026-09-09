// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../importer.dart';
import '../embedded_sass.pb.dart' hide SourceSpan;
import 'base.dart';

/// An importer that asks the host to resolve imports in a simplified,
/// file-system-centric way.
@internal
final class FileImporter(
  super.dispatcher,

  /// The host-provided ID of the importer to invoke.
  final int _importerId,
) extends ImporterBase {
  @override
  Uri? canonicalize(Uri url) {
    if (url.scheme == 'file') {
      return FilesystemImporter.noLoadPath.canonicalize(url);
    }

    var request = OutboundMessage_FileImportRequest()
      ..importerId = _importerId
      ..url = url.toString()
      ..fromImport = fromImport;
    if (canonicalizeContext.containingUrlWithoutMarking
        case var containingUrl?) {
      request.containingUrl = containingUrl.toString();
    }
    var response = dispatcher.sendFileImportRequest(request);
    if (!response.containingUrlUnused) canonicalizeContext.containingUrl;

    switch (response.whichResult()) {
      case .fileUrl:
        var url = parseAbsoluteUrl("The file importer", response.fileUrl);
        if (url.scheme != 'file') {
          throw 'The file importer must return a file: URL, was "$url"';
        }

        return FilesystemImporter.noLoadPath.canonicalize(url);

      case .error:
        throw response.error;

      case .notSet:
        return null;
    }
  }

  @override
  ImporterResult? load(Uri url) => FilesystemImporter.noLoadPath.load(url);

  @override
  bool isNonCanonicalScheme(String scheme) => scheme != 'file';

  @override
  String toString() => "FileImporter";
}
