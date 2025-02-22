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

/**
 * The initializer properties for {@link ParenthesizedExpression}.
 *
 * @category Expression
 */
export interface ParenthesizedExpressionProps extends NodeProps {
  inParens: AnyExpression | ExpressionProps;
  raws?: ParenthesizedExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link ParenthesizedExpression}.
 *
 * @category Expression
 */
export interface ParenthesizedExpressionRaws {
  /** The whitespace after the opening parenthesis. */
  afterOpen?: string;

  /** The whitespace before the closing parenthesis. */
  beforeClose?: string;
}

/**
 * An expression representing a parenthesized Sass expression.
 *
 * @category Expression
 */
export class ParenthesizedExpression extends Expression {
  readonly sassType = 'parenthesized' as const;
  declare raws: ParenthesizedExpressionRaws;

  /** The expression within the parentheses. */
  get inParens(): AnyExpression {
    return this._inParens;
  }
  set inParens(inParens: AnyExpression | ExpressionProps) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._inParens) this._inParens.parent = undefined;
    const built = 'sassType' in inParens ? inParens : fromProps(inParens);
    built.parent = this;
    this._inParens = built;
  }
  private declare _inParens: AnyExpression;

  constructor(defaults: ParenthesizedExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ParenthesizedExpression);
  constructor(defaults?: object, inner?: sassInternal.ParenthesizedExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.inParens = convertExpression(inner.expression);
    }
  }

  clone(overrides?: Partial<ParenthesizedExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'inParens']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['inParens'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      '(' +
      (this.raws.afterOpen ?? '') +
      this.inParens +
      (this.raws.beforeClose ?? '') +
      ')'
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyExpression> {
    return [this.inParens];
  }
}
