// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../comment.dart';
import 'node.dart';

/// A modifiable version of [CssComment] for use in the evaluation step.
final class ModifiableCssComment(
  @override final String text,
  @override final FileSpan span,
) extends ModifiableCssNode implements CssComment {
  @override
  bool get isPreserved => text.codeUnitAt(2) == $exclamation;

  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) => visitor.visitCssComment(this);
}
