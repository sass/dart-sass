// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import '../importer.dart';
import '../syntax.dart';

/// The result of importing a Sass stylesheet, as returned by [Importer.load].
///
/// {@category Importer}
final class ImporterResult {
  /// The contents of the stylesheet.
  final String contents;

  /// An absolute, browser-accessible URL indicating the resolved location of
  /// the imported stylesheet.
  ///
  /// This should be a `file:` URL if one is available, but an `http:` URL is
  /// acceptable as well. If no URL is supplied, a `data:` URL is generated
  /// automatically from [contents].
  Uri get sourceMapUrl =>
      _sourceMapUrl ?? Uri.dataFromString(contents, encoding: utf8);
  final Uri? _sourceMapUrl;

  /// The syntax to use to parse the stylesheet.
  final Syntax syntax;

  /// Creates a new [ImporterResult].
  ImporterResult(
    this.contents, {
    Uri? sourceMapUrl,
    required this.syntax,
  }) : _sourceMapUrl = sourceMapUrl {
    if (sourceMapUrl?.scheme == '') {
      throw ArgumentError.value(
        sourceMapUrl,
        'sourceMapUrl',
        'must be absolute',
      );
    }
  }
}
