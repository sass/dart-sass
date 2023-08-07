// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../util/span.dart';
import '../../../visitor/interface/statement.dart';
import '../argument_declaration.dart';
import '../declaration.dart';
import '../statement.dart';
import 'callable_declaration.dart';
import 'silent_comment.dart';

/// A function declaration.
///
/// This declares a function that's invoked using normal CSS function syntax.
///
/// {@category AST}
final class FunctionRule extends CallableDeclaration
    implements SassDeclaration {
  FileSpan get nameSpan => span.withoutInitialAtRule().initialIdentifier();

  FunctionRule(String name, ArgumentDeclaration arguments,
      Iterable<Statement> children, FileSpan span,
      {SilentComment? comment})
      : super(name, arguments, children, span, comment: comment);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitFunctionRule(this);

  String toString() => "@function $name($arguments) {${children.join(' ')}}";
}
