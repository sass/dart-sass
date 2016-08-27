// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/statement.dart';
import 'argument_declaration.dart';
import 'statement.dart';

class MixinDeclaration extends CallableDeclaration {
  MixinDeclaration(String name, ArgumentDeclaration arguments,
      Iterable<Statement> children, {FileSpan span})
      : super(name, arguments, children, span: span);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitMixinDeclaration(this);

  String toString() => "@mixin $name($arguments) {${children.join(' ')}}";
}
