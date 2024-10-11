// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link NumberExpression}.
 *
 * @category Expression
 */
export interface NumberExpressionProps {
  value: number;
  unit?: string;
  raws?: NumberExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link NumberExpression}.
 *
 * @category Expression
 */
export interface NumberExpressionRaws {
  /**
   * The raw string representation of the number.
   *
   * Numbers can be represented with or without leading and trailing zeroes, and
   * use scientific notation. For example, the following number representations
   * have the same value: `1e3`, `1000`, `01000.0`.
   */
  raw?: string;

  /**
   * The numeric value for the raw string that represents the number.
   *
   * This `value` is compared with {@link NumberExpression.value}. If they
   * match, then the {@link raw} string is output when stringifying the
   * expression. Otherwise, the {@link raw} string is ignored, and the
   * {@link NumberExpression.value} is output.
   */
  value?: number;
}

/**
 * An expression representing a number literal in Sass.
 *
 * @category Expression
 */
export class NumberExpression extends Expression {
  readonly sassType = 'number' as const;
  declare raws: NumberExpressionRaws;

  /** The numeric value of this expression. */
  get value(): number {
    return this._value;
  }
  set value(value: number) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._value = value;
  }
  private _value!: number;

  /** The denominator units of this number. */
  get unit(): string | null {
    return this._unit;
  }
  set unit(unit: string | null) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._unit = unit;
  }
  private _unit!: string | null;

  /** Whether the number is unitless. */
  isUnitless(): boolean {
    return this.unit === null;
  }

  constructor(defaults: NumberExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.NumberExpression);
  constructor(defaults?: object, inner?: sassInternal.NumberExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.value = inner.value;
      this.unit = inner.unit;
    } else {
      this.value ??= 0;
      this.unit ??= null;
    }
  }

  clone(overrides?: Partial<NumberExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'value', 'unit']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['value', 'unit'], inputs);
  }

  /** @hidden */
  toString(): string {
    if (this.raws?.raw != null && this.raws?.value === this.value) {
      return this.raws.raw + (this.unit ?? '');
    }
    return this.value + (this.unit ?? '');
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [];
  }
}
