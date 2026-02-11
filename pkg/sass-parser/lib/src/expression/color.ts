// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import * as sass from 'sass';

import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import {RawWithValue} from '../raw-with-value';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link ColorExpression}.
 *
 * @category Expression
 */
export interface ColorExpressionProps extends NodeProps {
  raws?: ColorExpressionRaws;

  /**
   * The color value for the expression. This must be in the RGB color space,
   * or {@link ColorExpression} will throw an error.
   */
  value: sass.SassColor;
}

/**
 * Raws indicating how to precisely serialize a {@link ColorExpression}.
 *
 * @category Expression
 */
export interface ColorExpressionRaws {
  /**
   * The raw string representation of the color.
   *
   * Colors can be represented as named keywords or as hex codes, with or
   * without capitalizations and with a varying number of digits.
   */
  value?: RawWithValue<sass.SassColor>;
}

/**
 * An expression representing a color literal in Sass.
 *
 * @category Expression
 */
export class ColorExpression extends Expression {
  readonly sassType = 'color' as const;
  declare raws: ColorExpressionRaws;

  /**
   * The color represented by this expression. This will always be a color in
   * the RGB color space.
   *
   * Throws an error if this is set to a non-RGB color.
   */
  get value(): sass.SassColor {
    return this._value;
  }
  set value(value: sass.SassColor) {
    if (value.space !== 'rgb') {
      throw new Error(
        `Can't set ColorExpression.color to ${value}. Only RGB colors can ` +
          'be represented as color literals.',
      );
    }

    // TODO - postcss/postcss#1957: Mark this as dirty
    this._value = value;
  }
  declare private _value: sass.SassColor;

  constructor(defaults: ColorExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ColorExpression);
  constructor(defaults?: object, inner?: sassInternal.ColorExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.value = inner.value;
    }
  }

  clone(overrides?: Partial<ColorExpressionProps>): this {
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
    return this.raws?.value?.value?.equals(this.value)
      ? this.raws.value.raw
      : '#' +
          (['red', 'green', 'blue'] as const)
            .map(name =>
              Math.round(this.value.channel(name))
                .toString(16)
                .padStart(2, '0'),
            )
            .join('') +
          (this.value.alpha >= 1
            ? ''
            : Math.round(this.value.alpha * 255)
                .toString(16)
                .padStart(2, '0'));
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<never> {
    return [];
  }
}
