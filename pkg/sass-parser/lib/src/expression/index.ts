// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Node} from '../node';
import type {
  BinaryOperationExpression,
  BinaryOperationExpressionProps,
} from './binary-operation';
import type {StringExpression, StringExpressionProps} from './string';

/**
 * The union type of all Sass expressions.
 *
 * @category Expression
 */
export type AnyExpression = BinaryOperationExpression | StringExpression;

/**
 * Sass expression types.
 *
 * @category Expression
 */
export type ExpressionType = 'binary-operation' | 'string';

/**
 * The union type of all properties that can be used to construct Sass
 * expressions.
 *
 * @category Expression
 */
export type ExpressionProps =
  | BinaryOperationExpressionProps
  | StringExpressionProps;

/**
 * The superclass of Sass expression nodes.
 *
 * An expressions is anything that can appear in a variable value,
 * interpolation, declaration value, and so on.
 *
 * @category Expression
 */
export abstract class Expression extends Node {
  abstract readonly sassType: ExpressionType;
  abstract clone(overrides?: object): this;
}
