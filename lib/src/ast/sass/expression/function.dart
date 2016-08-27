// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../statement.dart';

class FunctionExpression implements Expression, CallableInvocation {
  final Interpolation name;

  final ArgumentInvocation arguments;

  FileSpan get span => spanForList([name, arguments]);

  FunctionExpression(this.name, this.arguments);

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitFunctionExpression(this);

  String toString() => "$name$arguments";
}
