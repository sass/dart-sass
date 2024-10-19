// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sassInternal from '../sass-internal';

import {BinaryOperationExpression} from './binary-operation';
import {StringExpression} from './string';
import {Expression} from '.';
import {BooleanExpression} from './boolean';
import {NumberExpression} from './number';

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor = sassInternal.createExpressionVisitor<Expression>({
  visitBinaryOperationExpression: inner =>
    new BinaryOperationExpression(undefined, inner),
  visitStringExpression: inner => new StringExpression(undefined, inner),
  visitBooleanExpression: inner => new BooleanExpression(undefined, inner),
  visitNumberExpression: inner => new NumberExpression(undefined, inner),
});

/** Converts an internal expression AST node into an external one. */
export function convertExpression(
  expression: sassInternal.Expression
): Expression {
  return expression.accept(visitor);
}
