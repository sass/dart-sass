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
 * The initializer properties for {@link NullExpression}.
 *
 * @category Expression
 */
export interface NullExpressionProps extends NodeProps {
  value: null;
  raws?: NullExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link NullExpression}.
 *
 * @category Expression
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a boolean expression yet.
export interface NullExpressionRaws {}

/**
 * An expression representing a null literal in Sass.
 *
 * @category Expression
 */
export class NullExpression extends Expression {
  readonly sassType = 'null' as const;
  declare raws: NullExpressionRaws;

  /**
   * The value of this expression. Always null.
   *
   * This is only present for consistency with other literal types.
   */
  get value(): null {
    return null;
  }
  set value(value: null) {
    // Do nothing; value is already null. This is only necessary so that we can
    // have `value: null` in `NullExpressionProps` for consistency with other
    // literal types.
  }

  constructor(defaults?: Partial<NullExpressionProps>);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.NullExpression);
  constructor(defaults?: object, inner?: sassInternal.NullExpression) {
    super(defaults);
    if (inner) this.source = new LazySource(inner);
  }

  clone(overrides?: Partial<NullExpressionProps>): this {
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
    return 'null';
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<never> {
    return [];
  }
}
