// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../import.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssImport] for use in the evaluation step.
final class ModifiableCssImport extends ModifiableCssNode implements CssImport {
  /// The URL being imported.
  ///
  /// This includes quotes.
  @override
  final CssValue<String> url;

  @override
  final CssValue<String>? modifiers;

  @override
  final FileSpan span;

  ModifiableCssImport(this.url, this.span, {this.modifiers});

  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) => visitor.visitCssImport(this);
}
