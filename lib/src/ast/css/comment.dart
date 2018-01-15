// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';

/// A plain CSS comment.
///
/// This is always a multi-line comment.
class CssComment extends CssNode {
  /// The contents of this comment, including `/*` and `*/`.
  final String text;

  final FileSpan span;

  /// Whether this comment starts with `/*!` and so should be preserved even in
  /// compressed mode.
  bool get isPreserved => text.codeUnitAt(2) == $exclamation;

  CssComment(this.text, this.span);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitComment(this);
}
