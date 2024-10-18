// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link BooleanExpression}.
 *
 * @category Expression
 */
export interface BooleanExpressionProps {
  value: boolean;
  raws?: BooleanExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link BooleanExpression}.
 *
 * @category Expression
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a boolean expression yet.
export interface BooleanExpressionRaws {}

/**
 * An expression representing a boolean literal in Sass.
 *
 * @category Expression
 */
export class BooleanExpression extends Expression {
  readonly sassType = 'boolean' as const;
  declare raws: BooleanExpressionRaws;

  /** The boolean value of this expression. */
  get value(): boolean {
    return this._value;
  }
  set value(value: boolean) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._value = value;
  }
  private _value!: boolean;

  constructor(defaults: BooleanExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.BooleanExpression);
  constructor(defaults?: object, inner?: sassInternal.BooleanExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.value = inner.value;
    } else {
      this.value ??= false;
    }
  }

  clone(overrides?: Partial<BooleanExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'value']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['value'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.value ? 'true' : 'false';
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [];
  }
}
