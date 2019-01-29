// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/css.dart';
import '../at_rule.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssAtRule] for use in the evaluation step.
class ModifiableCssAtRule extends ModifiableCssParentNode implements CssAtRule {
  final CssValue<String> name;
  final CssValue<String> value;
  final bool isChildless;
  final FileSpan span;

  ModifiableCssAtRule(this.name, this.span,
      {bool childless = false, this.value})
      : isChildless = childless;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitAtRule(this);

  ModifiableCssAtRule copyWithoutChildren() =>
      ModifiableCssAtRule(name, span, childless: isChildless, value: value);

  void addChild(ModifiableCssNode child) {
    assert(!isChildless);
    super.addChild(child);
  }
}
