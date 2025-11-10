// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {NodeProps} from '../../node';
import type * as sassInternal from '../../sass-internal';
import * as utils from '../../utils';
import {fromProps} from './from-props';
import {
  AnyIfConditionExpression,
  IfConditionExpression,
  IfConditionExpressionProps,
} from './index';
import {IfEntry} from '../if-entry';
import {LazySource} from '../../lazy-source';
import {convertIfConditionExpression} from './convert';

/**
 * The set of raws supported by {@link IfConditionNegation}.
 *
 * @category Expression
 */
export interface IfConditionNegationRaws {
  /** The exact formatting of the `not` keyword. */
  not?: string;

  /** The whitespace between the `not` and the condition. */
  between?: string;
}

/**
 * The initializer properties for {@link IfConditionNegation}.
 *
 * @category Expression
 */
export interface IfConditionNegationProps extends NodeProps {
  raws?: IfConditionNegationRaws;
  negated: AnyIfConditionExpression | IfConditionExpressionProps;
}

/**
 * A negated condition in an `if()` condition.
 *
 * @category Expression
 */
export class IfConditionNegation extends IfConditionExpression {
  readonly sassType = 'if-condition-negation' as const;
  declare raws: IfConditionNegationRaws;
  declare parent: IfEntry | AnyIfConditionExpression | undefined;

  /** The negated condition. */
  get negated(): AnyIfConditionExpression {
    return this._negated!;
  }
  set negated(negated: AnyIfConditionExpression | IfConditionExpressionProps) {
    if (this._negated) this._negated.parent = undefined;
    const built = fromProps(negated);
    built.parent = this;
    this._negated = built;
  }
  private declare _negated?: AnyIfConditionExpression;

  constructor(
    defaults:
      | IfConditionNegationProps
      | AnyIfConditionExpression
      | IfConditionExpressionProps,
  );
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfConditionNegation);
  constructor(defaults?: object, inner?: sassInternal.IfConditionNegation) {
    if (defaults && !('negated' in defaults)) {
      defaults = {negated: defaults};
    }
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.negated = convertIfConditionExpression(inner.expression);
    }
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfConditionNegationProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'negated']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['negated'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (this.raws.not ?? 'not') + (this.raws.between ?? ' ') + this.negated;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyIfConditionExpression> {
    return [this.negated];
  }
}
