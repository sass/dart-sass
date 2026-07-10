// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../supports_rule.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssSupportsRule] for use in the evaluation step.
final class ModifiableCssSupportsRule extends ModifiableCssParentNode
    implements CssSupportsRule {
  @override
  final CssValue<String> condition;

  @override
  final FileSpan span;

  ModifiableCssSupportsRule(this.condition, this.span);

  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssSupportsRule(this);

  @override
  bool equalsIgnoringChildren(ModifiableCssNode other) =>
      other is ModifiableCssSupportsRule && condition == other.condition;

  @override
  ModifiableCssSupportsRule copyWithoutChildren() =>
      ModifiableCssSupportsRule(condition, span);
}
