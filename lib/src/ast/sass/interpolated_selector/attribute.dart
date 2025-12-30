// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../css/value.dart';
import '../../sass/interpolation.dart';
import '../../selector.dart';
import 'qualified_name.dart';
import 'simple.dart';

/// An attribute selector.
///
/// Unlike [AttributeSelector], this is parsed during the initial stylesheet
/// parse when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedAttributeSelector extends InterpolatedSimpleSelector {
  /// The name of the attribute being selected for.
  final InterpolatedQualifiedName name;

  /// The operator that defines the semantics of [value].
  ///
  /// This is `null` if and only if [value] is `null`.
  final CssValue<AttributeOperator>? op;

  /// An assertion about the value of [name].
  ///
  /// This is `null` if and only if [op] is `null`.
  final Interpolation? value;

  /// The modifier which indicates how the attribute selector should be
  /// processed.
  ///
  /// If [op] is `null`, this is always `null` as well.
  final Interpolation? modifier;

  final FileSpan span;

  /// Creates an attribute selector that matches any element with a property of
  /// the given name.
  InterpolatedAttributeSelector(this.name, this.span)
      : op = null,
        value = null,
        modifier = null;

  /// Creates an attribute selector that matches an element with a property
  /// named [name], whose value matches [value] based on the semantics of [op].
  InterpolatedAttributeSelector.withOperator(
    this.name,
    this.op,
    this.value,
    this.span, {
    this.modifier,
  });

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitAttributeSelector(this);

  String toString() {
    var result = '[$name';
    if (op != null) {
      result += '$op$value';
      if (modifier != null) result += ' $modifier';
    }
    return result;
  }
}
