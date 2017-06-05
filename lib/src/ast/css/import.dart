// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'media_query.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS `@import`.
class CssImport extends CssNode {
  /// The URL being imported.
  ///
  /// This includes quotes.
  final CssValue<String> url;

  /// The supports condition attached to this import.
  final CssValue<String> supports;

  /// The media query attached to this import.
  final List<CssMediaQuery> media;

  final FileSpan span;

  CssImport(this.url, this.span, {this.supports, Iterable<CssMediaQuery> media})
      : media = media == null ? null : new List.unmodifiable(media);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitImport(this);
}
