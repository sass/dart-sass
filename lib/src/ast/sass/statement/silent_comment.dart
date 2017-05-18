// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';

/// A silent Sass-style comment.
class SilentComment implements Statement {
  /// The text of this comment, including comment characters.
  final String text;

  final FileSpan span;

  SilentComment(this.text, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitSilentComment(this);

  String toString() => text;
}
