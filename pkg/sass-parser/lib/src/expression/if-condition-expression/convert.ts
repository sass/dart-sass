// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sassInternal from '../../sass-internal';

import {AnyIfConditionExpression} from '.';
import {IfConditionSass} from './sass';
import {IfConditionParenthesized} from './parenthesized';
import {IfConditionNegation} from './negation';
import {IfConditionOperation} from './operation';

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor =
  sassInternal.createIfConditionExpressionVisitor<AnyIfConditionExpression>({
    visitIfConditionNegation: inner =>
      new IfConditionNegation(undefined, inner),
    visitIfConditionOperation: inner =>
      new IfConditionOperation(undefined, inner),
    visitIfConditionParenthesized: inner =>
      new IfConditionParenthesized(undefined, inner),
    visitIfConditionSass: inner => new IfConditionSass(undefined, inner),
  });

/**
 * Converts an internal `if()` condition expression AST node into an external
 * one.
 */
export function convertIfConditionExpression(
  expression: sassInternal.IfConditionExpression,
): AnyIfConditionExpression {
  return expression.accept(visitor);
}
