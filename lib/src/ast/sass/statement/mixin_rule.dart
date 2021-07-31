// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../../../visitor/statement_search.dart';
import '../argument_declaration.dart';
import '../statement.dart';
import 'callable_declaration.dart';
import 'silent_comment.dart';

/// A mixin declaration.
///
/// This declares a mixin that's invoked using `@include`.
class MixinRule extends CallableDeclaration {
  /// Whether the mixin contains a `@content` rule.
  late final bool hasContent =
      const _HasContentVisitor().visitMixinRule(this) == true;

  MixinRule(String name, ArgumentDeclaration arguments,
      Iterable<Statement> children, FileSpan span,
      {SilentComment? comment})
      : super(name, arguments, children, span, comment: comment);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitMixinRule(this);

  String toString() {
    var buffer = StringBuffer("@mixin $name");
    if (!arguments.isEmpty) buffer.write("($arguments)");
    buffer.write(" {${children.join(' ')}}");
    return buffer.toString();
  }
}

/// A visitor for determining whether a [MixinRule] recursively contains a
/// [ContentRule].
class _HasContentVisitor extends StatementSearchVisitor<bool> {
  const _HasContentVisitor();

  bool visitContentRule(_) => true;
  bool? visitArgumentInvocation(_) => null;
  bool? visitSupportsCondition(_) => null;
  bool? visitInterpolation(_) => null;
}
