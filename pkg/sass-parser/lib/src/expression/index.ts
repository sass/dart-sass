// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Node} from '../node';
import type {
  BinaryOperationExpression,
  BinaryOperationExpressionProps,
} from './binary-operation';
import {BooleanExpression, BooleanExpressionProps} from './boolean';
import {ColorExpression, ColorExpressionProps} from './color';
import {FunctionExpression, FunctionExpressionProps} from './function';
import {ListExpression, ListExpressionProps} from './list';
import {MapExpression, MapExpressionProps} from './map';
import {NumberExpression, NumberExpressionProps} from './number';
import type {StringExpression, StringExpressionProps} from './string';

/**
 * The union type of all Sass expressions.
 *
 * @category Expression
 */
export type AnyExpression =
  | BinaryOperationExpression
  | BooleanExpression
  | ColorExpression
  | FunctionExpression
  | ListExpression
  | MapExpression
  | NumberExpression
  | StringExpression;

/**
 * Sass expression types.
 *
 * @category Expression
 */
export type ExpressionType =
  | 'binary-operation'
  | 'boolean'
  | 'color'
  | 'function-call'
  | 'list'
  | 'map'
  | 'number'
  | 'string';

/**
 * The union type of all properties that can be used to construct Sass
 * expressions.
 *
 * @category Expression
 */
export type ExpressionProps =
  | BinaryOperationExpressionProps
  | BooleanExpressionProps
  | ColorExpressionProps
  | FunctionExpressionProps
  | ListExpressionProps
  | MapExpressionProps
  | NumberExpressionProps
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
