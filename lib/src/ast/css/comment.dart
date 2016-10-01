// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

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

  CssComment(this.text, this.span);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) => visitor.visitComment(this);
}
