// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_declaration.dart';
import '../statement.dart';
import 'callable_declaration.dart';

/// A function declaration.
///
/// This declares a function that's invoked using normal CSS function syntax.
class FunctionRule extends CallableDeclaration {
  FunctionRule(String name, ArgumentDeclaration arguments,
      Iterable<Statement> children, FileSpan span)
      : super(name, arguments, children, span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitFunctionRule(this);

  String toString() => "@function $name($arguments) {${children.join(' ')}}";
}
