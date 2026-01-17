// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {AnyExpression, Expression, ExpressionProps} from '.';
import {convertExpression} from './convert';
import {fromProps} from './from-props';

/** Different unary operations supported by Sass. */
export type UnaryOperator = '+' | '-' | '/' | 'not';

/**
 * The initializer properties for {@link UnaryOperationExpression}.
 *
 * @category Expression
 */
export interface UnaryOperationExpressionProps extends NodeProps {
  operator: UnaryOperator;
  operand: AnyExpression | ExpressionProps;
  raws?: UnaryOperationExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link UnaryOperationExpression}.
 *
 * @category Expression
 */
export interface UnaryOperationExpressionRaws {
  /** The whitespace between the operator and operand. */
  between?: string;
}

/**
 * An expression representing a unary operation in Sass.
 *
 * @category Expression
 */
export class UnaryOperationExpression extends Expression {
  readonly sassType = 'unary-operation' as const;
  declare raws: UnaryOperationExpressionRaws;

  /** Which operator this operation uses. */
  get operator(): UnaryOperator {
    return this._operator;
  }
  set operator(operator: UnaryOperator) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._operator = operator;
  }
  declare private _operator: UnaryOperator;

  /** The expression that this operation acts on. */
  get operand(): AnyExpression {
    return this._operand;
  }
  set operand(operand: AnyExpression | ExpressionProps) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._operand) this._operand.parent = undefined;
    const built = 'sassType' in operand ? operand : fromProps(operand);
    built.parent = this;
    this._operand = built;
  }
  declare private _operand: AnyExpression;

  constructor(defaults: UnaryOperationExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.UnaryOperationExpression);
  constructor(
    defaults?: object,
    inner?: sassInternal.UnaryOperationExpression,
  ) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.operator = inner.operator.operator;
      this.operand = convertExpression(inner.operand);
    }
  }

  clone(overrides?: Partial<UnaryOperationExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'operator', 'operand']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['operator', 'operand'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      this.operator +
      (this.raws.between ??
        (this.operator === 'not' ||
        (this.operator === '-' &&
          ((this.operand.sassType === 'string' && !this.operand.quotes) ||
            this.operand.sassType === 'function-call' ||
            this.operand.sassType === 'interpolated-function-call')) ||
        this.operand.sassType === 'number'
          ? ' '
          : '')) +
      this.operand
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyExpression> {
    return [this.operand];
  }
}
