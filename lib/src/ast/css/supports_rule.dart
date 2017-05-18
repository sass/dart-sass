// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS `@supports` rule.
class CssSupportsRule extends CssParentNode {
  /// The supports condition.
  final CssValue<String> condition;

  final FileSpan span;

  CssSupportsRule(this.condition, this.span);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitSupportsRule(this);

  CssSupportsRule copyWithoutChildren() => new CssSupportsRule(condition, span);
}
