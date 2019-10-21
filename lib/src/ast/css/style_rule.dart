// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/css.dart';
import '../selector.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS style rule.
///
/// This applies style declarations to elements that match a given selector.
/// Note that this isn't *strictly* plain CSS, since [selector] may still
/// contain placeholder selectors.
abstract class CssStyleRule extends CssParentNode {
  /// The selector for this rule.
  CssValue<SelectorList> get selector;

  /// The selector for this rule, before any extensions were applied.
  SelectorList get originalSelector;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitCssStyleRule(this);
}
