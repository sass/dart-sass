// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../importer.dart';
import '../dispatcher.dart';

/// An abstract base class for importers that communicate with the host in some
/// way.
abstract base class ImporterBase extends Importer {
  /// The [Dispatcher] to which to send requests.
  @protected
  final Dispatcher dispatcher;

  ImporterBase(this.dispatcher);

  /// Parses [url] as a [Uri] and throws an error if it's invalid or relative
  /// (including root-relative).
  ///
  /// The [source] name is used in the error message if one is thrown.
  @protected
  Uri parseAbsoluteUrl(String source, String url) {
    Uri parsedUrl;
    try {
      parsedUrl = Uri.parse(url);
    } on FormatException {
      throw '$source must return a URL, was "$url"';
    }

    if (parsedUrl.scheme.isNotEmpty) return parsedUrl;
    throw '$source must return an absolute URL, was "$parsedUrl"';
  }
}
