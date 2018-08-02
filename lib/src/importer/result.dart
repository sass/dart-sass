// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';

import '../importer.dart';
import '../syntax.dart';

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
      _sourceMapUrl ?? new Uri.dataFromString(contents, encoding: utf8);
  final Uri _sourceMapUrl;

  /// The syntax to use to parse the stylesheet.
  final Syntax syntax;

  @Deprecated("Use syntax instead.")
  bool get isIndented => syntax == Syntax.sass;

  /// Creates a new [ImporterResult].
  ///
  /// The [syntax] parameter must be passed. It's not marked as required only
  /// because old clients may still be passing the deprecated [indented]
  /// parameter instead.
  ImporterResult(this.contents,
      {Uri sourceMapUrl,
      Syntax syntax,
      @Deprecated("Use the syntax parameter instead.") bool indented})
      : _sourceMapUrl = sourceMapUrl,
        syntax = syntax ?? (indented == true ? Syntax.sass : Syntax.scss) {
    if (sourceMapUrl?.scheme == '') {
      throw new ArgumentError.value(
          sourceMapUrl, 'sourceMapUrl', 'must be absolute');
    } else if (syntax == null && indented == null) {
      throw new ArgumentError("The syntax parameter must be passed.");
    } else if (syntax != null && indented != null) {
      throw new ArgumentError("Only one of syntax and indented may be passed.");
    }
  }
}
