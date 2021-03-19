// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../keyframe_block.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssKeyframeBlock] for use in the evaluation step.
class ModifiableCssKeyframeBlock extends ModifiableCssParentNode
    implements CssKeyframeBlock {
  final CssValue<List<String>> selector;
  final FileSpan span;

  ModifiableCssKeyframeBlock(this.selector, this.span);

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssKeyframeBlock(this);

  ModifiableCssKeyframeBlock copyWithoutChildren() =>
      ModifiableCssKeyframeBlock(selector, span);
}
