// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link SelectorExpression}.
 *
 * Unlike other expression types, this can't be initialized by properties alone,
 * since it doesn't have any properties to set.
 *
 * @category Expression
 */
export interface SelectorExpressionProps extends NodeProps {
  raws?: SelectorExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link SelectorExpression}.
 *
 * @category Expression
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a selector expression yet.
export interface SelectorExpressionRaws {}

/**
 * An expression representing the current selector in Sass.
 *
 * @category Expression
 */
export class SelectorExpression extends Expression {
  readonly sassType = 'selector-expr' as const;
  declare raws: SelectorExpressionRaws;

  constructor(defaults?: SelectorExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.SelectorExpression);
  constructor(defaults?: object, inner?: sassInternal.SelectorExpression) {
    super(defaults);
    if (inner) this.source = new LazySource(inner);
  }

  clone(overrides?: Partial<SelectorExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, [], inputs);
  }

  /** @hidden */
  toString(): string {
    return '&';
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [];
  }
}
