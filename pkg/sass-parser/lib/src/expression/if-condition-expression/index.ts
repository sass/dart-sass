// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Node} from '../../node';
import {IfConditionFunction, IfConditionFunctionProps} from './function';
import {IfConditionNegation, IfConditionNegationProps} from './negation';
import {IfConditionOperation, IfConditionOperationProps} from './operation';
import {
  IfConditionParenthesized,
  IfConditionParenthesizedProps,
} from './parenthesized';
import {IfConditionRaw, IfConditionRawProps} from './raw';
import type {IfConditionSass, IfConditionSassProps} from './sass';

/**
 * The union type of all `if()` condition expressions.
 *
 * @category Expression
 */
export type AnyIfConditionExpression =
  | IfConditionFunction
  | IfConditionNegation
  | IfConditionOperation
  | IfConditionParenthesized
  | IfConditionRaw
  | IfConditionSass;

/**
 * `if()` condition expression types.
 *
 * @category Expression
 */
export type IfConditionExpressionType =
  | 'if-condition-function'
  | 'if-condition-negation'
  | 'if-condition-operation'
  | 'if-condition-parenthesized'
  | 'if-condition-raw'
  | 'if-condition-sass';

/**
 * The union type of all properties that can be used to construct `if()`
 * condition expressions.
 *
 * @category Expression
 */
export type IfConditionExpressionProps =
  | IfConditionFunctionProps
  | IfConditionNegationProps
  | IfConditionOperationProps
  | IfConditionParenthesizedProps
  | IfConditionRawProps
  | IfConditionSassProps;

/**
 * The superclass of `if()` condition expression nodes.
 *
 * An `if()` condition expression is a subexpression that can appear in the
 * condition of a CSS-style `if()` function.
 *
 * @category Expression
 */
export abstract class IfConditionExpression extends Node {
  abstract readonly sassType: IfConditionExpressionType;
  abstract clone(overrides?: object): this;
}
