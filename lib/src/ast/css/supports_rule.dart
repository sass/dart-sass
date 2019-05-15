// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS `@supports` rule.
abstract class CssSupportsRule extends CssParentNode {
  /// The supports condition.
  CssValue<String> get condition;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitCssSupportsRule(this);
}
