// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../at_rule.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssAtRule] for use in the evaluation step.
final class ModifiableCssAtRule extends ModifiableCssParentNode
    implements CssAtRule {
  @override
  final CssValue<String> name;

  @override
  final CssValue<String>? value;

  @override
  final bool isChildless;

  @override
  final FileSpan span;

  ModifiableCssAtRule(
    this.name,
    this.span, {
    bool childless = false,
    this.value,
  }) : isChildless = childless;

  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) => visitor.visitCssAtRule(this);

  @override
  bool equalsIgnoringChildren(ModifiableCssNode other) =>
      other is ModifiableCssAtRule &&
      name == other.name &&
      value == other.value &&
      isChildless == other.isChildless;

  @override
  ModifiableCssAtRule copyWithoutChildren() =>
      ModifiableCssAtRule(name, span, childless: isChildless, value: value);

  @override
  void addChild(ModifiableCssNode child) {
    assert(!isChildless);
    super.addChild(child);
  }
}
