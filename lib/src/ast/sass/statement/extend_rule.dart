// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

/// An `@extend` rule.
///
/// This gives one selector all the styling of another.
///
/// {@category AST}
final class ExtendRule(
  /// The interpolation for the selector that will be extended.
  final Interpolation selector,
  @override final FileSpan span, {
  bool optional = false,
}) extends Statement {
  /// Whether this is an optional extension.
  ///
  /// If an extension isn't optional, it will emit an error if it doesn't match
  /// any selectors.
  final bool isOptional = optional;

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitExtendRule(this);

  @override
  String toString() => "@extend $selector${isOptional ? ' !optional' : ''};";
}
