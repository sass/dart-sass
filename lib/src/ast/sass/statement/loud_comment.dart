// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

/// A loud CSS-style comment.
class LoudComment implements Statement {
  /// The interpolated text of this comment, including comment characters.
  final Interpolation text;

  FileSpan get span => text.span;

  /// Whether this comment follows non-comment text on a line and should remain
  /// attached to that non-comment text when being serialized.
  final bool isTrailing;

  LoudComment(this.text, this.isTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitLoudComment(this);

  String toString() => text.toString();
}
