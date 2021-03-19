// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../stylesheet.dart';
import 'node.dart';

/// A modifiable version of [CssStylesheet] for use in the evaluation step.
class ModifiableCssStylesheet extends ModifiableCssParentNode
    implements CssStylesheet {
  final FileSpan span;

  ModifiableCssStylesheet(this.span);

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssStylesheet(this);

  ModifiableCssStylesheet copyWithoutChildren() =>
      ModifiableCssStylesheet(span);
}
