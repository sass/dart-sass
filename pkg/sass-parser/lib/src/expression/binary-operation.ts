// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression, ExpressionProps} from '.';
import {convertExpression} from './convert';
import {fromProps} from './from-props';

/** Different binary operations supported by Sass. */
export type BinaryOperator =
  | '='
  | 'or'
  | 'and'
  | '=='
  | '!='
  | '>'
  | '>='
  | '<'
  | '<='
  | '+'
  | '-'
  | '*'
  | '/'
  | '%';

/**
 * The initializer properties for {@link BinaryOperationExpression}.
 *
 * @category Expression
 */
export interface BinaryOperationExpressionProps {
  operator: BinaryOperator;
  left: Expression | ExpressionProps;
  right: Expression | ExpressionProps;
  raws?: BinaryOperationExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link BinaryOperationExpression}.
 *
 * @category Expression
 */
export interface BinaryOperationExpressionRaws {
  /** The whitespace before the operator. */
  beforeOperator?: string;

  /** The whitespace after the operator. */
  afterOperator?: string;
}

/**
 * An expression representing an inline binary operation Sass.
 *
 * @category Expression
 */
export class BinaryOperationExpression extends Expression {
  readonly sassType = 'binary-operation' as const;
  declare raws: BinaryOperationExpressionRaws;

  /**
   * Which operator this operation uses.
   *
   * Note that different operators have different precedence. It's the caller's
   * responsibility to ensure that operations are parenthesized appropriately to
   * guarantee that they're processed in AST order.
   *
   */
  get operator(): BinaryOperator {
    return this._operator;
  }
  set operator(operator: BinaryOperator) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._operator = operator;
  }
  private _operator!: BinaryOperator;

  /** The expression on the left-hand side of this operation. */
  get left(): Expression {
    return this._left;
  }
  set left(left: Expression | ExpressionProps) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._left) this._left.parent = undefined;
    if (!('sassType' in left)) left = fromProps(left);
    left.parent = this;
    this._left = left;
  }
  private _left!: Expression;

  /** The expression on the right-hand side of this operation. */
  get right(): Expression {
    return this._right;
  }
  set right(right: Expression | ExpressionProps) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._right) this._right.parent = undefined;
    if (!('sassType' in right)) right = fromProps(right);
    right.parent = this;
    this._right = right;
  }
  private _right!: Expression;

  constructor(defaults: BinaryOperationExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.BinaryOperationExpression);
  constructor(
    defaults?: object,
    inner?: sassInternal.BinaryOperationExpression
  ) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.operator = inner.operator.operator;
      this.left = convertExpression(inner.left);
      this.right = convertExpression(inner.right);
    }
  }

  clone(overrides?: Partial<BinaryOperationExpressionProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'operator',
      'left',
      'right',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['operator', 'left', 'right'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      `${this.left}${this.raws.beforeOperator ?? ' '}${this.operator}` +
      `${this.raws.afterOperator ?? ' '}${this.right}`
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.left, this.right];
  }
}
