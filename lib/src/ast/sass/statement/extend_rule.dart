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
class ExtendRule implements Statement {
  /// The interpolation for the selector that will be extended.
  final Interpolation selector;

  /// Whether this is an optional extension.
  ///
  /// If an extension isn't optional, it will emit an error if it doesn't match
  /// any selectors.
  final bool isOptional;

  final FileSpan span;

  ExtendRule(this.selector, this.span, {bool optional: false})
      : isOptional = optional;

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitExtendRule(this);

  String toString() => "@extend $selector";
}
