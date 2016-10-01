// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';

/// A comment, either silent (Sass-style) or loud (CSS-style).
class Comment implements Statement {
  /// The text of this comment, including comment characters.
  final String text;

  /// Whether this is a silent comment.
  final bool isSilent;

  final FileSpan span;

  Comment(this.text, this.span, {bool silent: false}) : isSilent = silent;

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitComment(this);

  String toString() => text;
}
