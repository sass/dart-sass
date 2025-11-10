// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sassInternal from '../../sass-internal';

import {AnyIfConditionExpression} from '.';
import {IfConditionSass} from './sass';
import {IfConditionParenthesized} from './parenthesized';
import {IfConditionNegation} from './negation';
import {IfConditionOperation} from './operation';
import {IfConditionFunction} from './function';
import {IfConditionRaw} from './raw';

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor =
  sassInternal.createIfConditionExpressionVisitor<AnyIfConditionExpression>({
    visitIfConditionFunction: inner =>
      new IfConditionFunction(undefined, inner),
    visitIfConditionNegation: inner =>
      new IfConditionNegation(undefined, inner),
    visitIfConditionOperation: inner =>
      new IfConditionOperation(undefined, inner),
    visitIfConditionParenthesized: inner =>
      new IfConditionParenthesized(undefined, inner),
    visitIfConditionRaw: inner => new IfConditionRaw(undefined, inner),
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
