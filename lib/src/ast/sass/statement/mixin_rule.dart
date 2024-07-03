// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../util/span.dart';
import '../../../visitor/interface/statement.dart';
import '../../../visitor/statement_search.dart';
import '../declaration.dart';
import '../parameter_list.dart';
import '../statement.dart';
import '../statement/silent_comment.dart';
import 'callable_declaration.dart';
import 'content_rule.dart';

/// A mixin declaration.
///
/// This declares a mixin that's invoked using `@include`.
///
/// {@category AST}
final class MixinRule extends CallableDeclaration implements SassDeclaration {
  /// Whether the mixin contains a `@content` rule.
  late final bool hasContent =
      const _HasContentVisitor().visitMixinRule(this) == true;

  FileSpan get nameSpan {
    var startSpan = span.text.startsWith('=')
        ? span.subspan(1).trimLeft()
        : span.withoutInitialAtRule();
    return startSpan.initialIdentifier();
  }

  MixinRule(String name, ParameterList parameters, Iterable<Statement> children,
      FileSpan span,
      {SilentComment? comment})
      : super(name, parameters, children, span, span.end, comment: comment);

  /// @nodoc
  @internal
  MixinRule.internal(super.name, super.parameters, super.children, super.span,
      super.afterTrailing,
      {super.comment});

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitMixinRule(this);

  String toString() {
    var buffer = StringBuffer("@mixin $name");
    if (!parameters.isEmpty) buffer.write("($parameters)");
    buffer.write(" {${children.join(' ')}}");
    return buffer.toString();
  }
}

/// A visitor for determining whether a [MixinRule] recursively contains a
/// [ContentRule].
class _HasContentVisitor with StatementSearchVisitor<bool> {
  const _HasContentVisitor();

  bool visitContentRule(_) => true;
}
