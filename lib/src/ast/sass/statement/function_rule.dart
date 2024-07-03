// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../util/span.dart';
import '../../../visitor/interface/statement.dart';
import '../declaration.dart';
import '../parameter_list.dart';
import '../statement.dart';
import '../statement/silent_comment.dart';
import 'callable_declaration.dart';

/// A function declaration.
///
/// This declares a function that's invoked using normal CSS function syntax.
///
/// {@category AST}
final class FunctionRule extends CallableDeclaration
    implements SassDeclaration {
  FileSpan get nameSpan => span.withoutInitialAtRule().initialIdentifier();

  FunctionRule(String name, ParameterList parameters,
      Iterable<Statement> children, FileSpan span,
      {SilentComment? comment})
      : super(name, parameters, children, span, span.end, comment: comment);

  /// @nodoc
  @internal
  FunctionRule.internal(super.name, super.parameters, super.children,
      super.span, super.afterTrailing,
      {super.comment});

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitFunctionRule(this);

  String toString() => "@function $name($parameters) {${children.join(' ')}}";
}
