// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass/expression.dart';
import '../../ast/sass/expression/identifier.dart';
import '../../ast/sass/expression/interpolation.dart';
import '../../ast/sass/expression/list.dart';
import '../../ast/sass/expression/string.dart';
import '../../ast/sass/expression/variable.dart';
import '../../environment.dart';
import '../../value.dart';
import '../../value/identifier.dart';
import '../../value/list.dart';
import '../../value/string.dart';
import '../expression.dart';

class PerformExpressionVisitor extends ExpressionVisitor<Value> {
  final Environment _environment;

  PerformExpressionVisitor(this._environment);

  Value visit(Expression expression) => expression.visit(this);

  Value visitVariableExpression(VariableExpression node) {
    var result = _environment.getVariable(node.name);
    if (result != null) return result;

    // TODO: real exception
    throw node.span.message("undefined variable");
  }

  Identifier visitIdentifierExpression(IdentifierExpression node) =>
      new Identifier(visitInterpolationExpression(node.text).text);

  SassString visitInterpolationExpression(InterpolationExpression node) {
    return new SassString(node.contents.map((value) {
      if (value is String) return value;
      return (value as Expression).visit(this);
    }).join());
  }

  SassList visitListExpression(ListExpression node) => new SassList(
      node.contents.map((expression) => expression.visit(this)),
      node.separator);

  SassString visitStringExpression(StringExpression node) =>
      visitInterpolationExpression(node.text);
}
