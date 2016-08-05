// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/sass/statement.dart';
import 'expression.dart';
import 'statement.dart';

class ExtendRule implements Statement {
  final InterpolationExpression selector;

  final FileSpan span;

  ExtendRule(this.selector, {this.span});

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitExtendRule(this);

  String toString() => "@extend $selector";
}
