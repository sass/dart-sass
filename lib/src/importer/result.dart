// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:dart2_constant/convert.dart' as convert;

import 'package:meta/meta.dart';

import '../importer.dart';

/// The result of importing a Sass stylesheet, as returned by [Importer.load].
class ImporterResult {
  /// The contents of the stylesheet.
  final String contents;

  /// An absolute, browser-accessible URL indicating the resolved location of
  /// the imported stylesheet.
  ///
  /// This should be a `file:` URL if one is available, but an `http:` URL is
  /// acceptable as well. If no URL is supplied, a `data:` URL is generated
  /// automatically from [contents].
  Uri get sourceMapUrl =>
      _sourceMapUrl ?? new Uri.dataFromString(contents, encoding: convert.utf8);
  final Uri _sourceMapUrl;

  /// Whether the stylesheet uses the indented syntax.
  final bool isIndented;

  ImporterResult(this.contents, {Uri sourceMapUrl, @required bool indented})
      : _sourceMapUrl = sourceMapUrl,
        isIndented = indented {
    if (sourceMapUrl?.scheme == '') {
      throw new ArgumentError.value(
          sourceMapUrl, 'sourceMapUrl', 'must be absolute');
    }
  }
}
