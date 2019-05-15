// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/css.dart';
import 'media_query.dart';
import 'node.dart';

/// A plain CSS `@media` rule.
abstract class CssMediaRule extends CssParentNode {
  /// The queries for this rule.
  ///
  /// This is never empty.
  List<CssMediaQuery> get queries;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitCssMediaRule(this);
}
