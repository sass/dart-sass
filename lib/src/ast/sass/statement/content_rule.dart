// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';

/// A `@content` rule.
///
/// This is used in a mixin to include statement-level content passed by the
/// caller.
class ContentRule implements Statement {
  final FileSpan span;

  ContentRule(this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitContentRule(this);

  String toString() => "@content;";
}
