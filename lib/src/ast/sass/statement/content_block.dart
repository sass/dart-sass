// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';
import '../parameter_list.dart';
import 'callable_declaration.dart';

/// An anonymous block of code that's invoked for a [ContentRule].
///
/// {@category AST}
final class ContentBlock extends CallableDeclaration {
  ContentBlock(
    ParameterList parameters,
    Iterable<Statement> children,
    FileSpan span,
  ) : super("@content", parameters, children, span, span.end);

  /// @nodoc
  @internal
  ContentBlock.internal(ParameterList parameters, Iterable<Statement> children,
      FileSpan span, FileLocation afterTrailing)
      : super("@content", parameters, children, span, afterTrailing);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitContentBlock(this);

  String toString() =>
      (parameters.isEmpty ? "" : " using ($parameters)") +
      " {${children.join(' ')}}";
}
