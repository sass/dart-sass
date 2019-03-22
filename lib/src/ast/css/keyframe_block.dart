// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// A block within a `@keyframes` rule.
///
/// For example, `10% {opacity: 0.5}`.
abstract class CssKeyframeBlock extends CssParentNode {
  /// The selector for this block.
  CssValue<List<String>> get selector;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitCssKeyframeBlock(this);
}
