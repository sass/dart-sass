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

  LoudComment(this.text);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitLoudComment(this);

  String toString() => text.toString();
}
