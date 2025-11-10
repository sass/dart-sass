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
import {IfExpression} from './if';
import {
  InterpolatedFunctionExpression,
  InterpolatedFunctionExpressionProps,
} from './interpolated-function';
import {ListExpression, ListExpressionProps} from './list';
import {MapExpression, MapExpressionProps} from './map';
import {NullExpression, NullExpressionProps} from './null';
import {NumberExpression, NumberExpressionProps} from './number';
import {
  ParenthesizedExpression,
  ParenthesizedExpressionProps,
} from './parenthesized';
import type {SelectorExpression} from './selector';
import type {StringExpression, StringExpressionProps} from './string';
import type {
  UnaryOperationExpression,
  UnaryOperationExpressionProps,
} from './unary-operation';
import type {VariableExpression, VariableExpressionProps} from './variable';

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
  | IfExpression
  | InterpolatedFunctionExpression
  | ListExpression
  | MapExpression
  | NullExpression
  | NumberExpression
  | ParenthesizedExpression
  | SelectorExpression
  | StringExpression
  | UnaryOperationExpression
  | VariableExpression;

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
  | 'if-expr'
  | 'interpolated-function-call'
  | 'list'
  | 'map'
  | 'null'
  | 'number'
  | 'parenthesized'
  | 'selector-expr'
  | 'string'
  | 'unary-operation'
  | 'variable';

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
  // Don't include IfExpressionProps because it's potentially ambiguous with
  // MapExpressionProps.
  | InterpolatedFunctionExpressionProps
  | ListExpressionProps
  | MapExpressionProps
  | NullExpressionProps
  | NumberExpressionProps
  | ParenthesizedExpressionProps
  | StringExpressionProps
  | UnaryOperationExpressionProps
  | VariableExpressionProps;

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
