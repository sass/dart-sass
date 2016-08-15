// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import 'interpolation.dart';

class IdentifierExpression implements Expression {
  final InterpolationExpression text;

  FileSpan get span => text.span;

  IdentifierExpression(this.text);

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitIdentifierExpression(this);

  String toString() => text.toString();
}