// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_declaration.dart';
import '../interface/declaration.dart';
import '../statement.dart';
import 'callable_declaration.dart';
import 'silent_comment.dart';

/// A function declaration.
///
/// This declares a function that's invoked using normal CSS function syntax.
///
/// {@category AST}
@sealed
class FunctionRule extends CallableDeclaration implements SassDeclaration {
  FileSpan get nameSpan {
    var match = RegExp(r'@function\s*').matchAsPrefix(span.text);
    var start = match!.end;
    return span.subspan(start, start + name.length);
  }

  FunctionRule(String name, ArgumentDeclaration arguments,
      Iterable<Statement> children, FileSpan span,
      {SilentComment? comment})
      : super(name, arguments, children, span, comment: comment);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitFunctionRule(this);

  String toString() => "@function $name($arguments) {${children.join(' ')}}";
}
