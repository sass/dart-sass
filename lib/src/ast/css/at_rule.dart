// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// An unknown plain CSS at-rule.
class CssAtRule extends CssParentNode {
  /// The name of this rule.
  final String name;

  /// The value of this rule.
  final CssValue<String> value;

  /// Whether the rule has no children.
  ///
  /// This implies `children.isEmpty`, but the reverse is not true—for a rule
  /// like `@foo {}`, [children] is empty but [isChildless] is `false`.
  final bool isChildless;

  final FileSpan span;

  /// An unknown at-rule is never invisible.
  ///
  /// Because we don't know the semantics of unknown rules, we can't guarantee
  /// that (for example) `@foo {}` isn't meaningful.
  bool get isInvisible => false;

  CssAtRule(this.name, this.span, {bool childless: false, this.value})
      : isChildless = childless;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitAtRule(this);

  CssAtRule copyWithoutChildren() =>
      new CssAtRule(name, span, childless: isChildless, value: value);

  void addChild(CssNode child) {
    assert(!isChildless);
    super.addChild(child);
  }
}
