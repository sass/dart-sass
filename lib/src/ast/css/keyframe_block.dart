// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// A block within a `@keyframes` rule.
///
/// For example, `10% {opacity: 0.5}`.
class CssKeyframeBlock extends CssParentNode {
  /// The selector for this block.
  final CssValue<List<String>> selector;

  final FileSpan span;

  CssKeyframeBlock(this.selector, this.span);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitKeyframeBlock(this);

  CssKeyframeBlock copyWithoutChildren() =>
      new CssKeyframeBlock(selector, span);
}
