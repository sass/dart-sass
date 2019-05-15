// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../import.dart';
import '../media_query.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssImport] for use in the evaluation step.
class ModifiableCssImport extends ModifiableCssNode implements CssImport {
  /// The URL being imported.
  ///
  /// This includes quotes.
  final CssValue<String> url;

  /// The supports condition attached to this import.
  final CssValue<String> supports;

  /// The media query attached to this import.
  final List<CssMediaQuery> media;

  final FileSpan span;

  ModifiableCssImport(this.url, this.span,
      {this.supports, Iterable<CssMediaQuery> media})
      : media = media == null ? null : List.unmodifiable(media);

  T accept<T>(ModifiableCssVisitor<T> visitor) => visitor.visitCssImport(this);
}
