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
 * The set of raws supported by {@link IfConditionParenthesized}.
 *
 * @category Expression
 */
export interface IfConditionParenthesizedRaws {
  /** The whitespace after the opening parenthesis. */
  afterOpen?: string;

  /** The whitespace before the closing parenthesis. */
  beforeClose?: string;
}

/**
 * The initializer properties for {@link IfConditionParenthesized}.
 *
 * @category Expression
 */
export interface IfConditionParenthesizedProps extends NodeProps {
  raws?: IfConditionParenthesizedRaws;
  parenthesized: AnyIfConditionExpression | IfConditionExpressionProps;
}

/**
 * A parenthesized condition in an `if()` condition.
 *
 * @category Expression
 */
export class IfConditionParenthesized extends IfConditionExpression {
  readonly sassType = 'if-condition-parenthesized' as const;
  declare raws: IfConditionParenthesizedRaws;
  declare parent: IfEntry | AnyIfConditionExpression | undefined;

  /** The parenthesized condition. */
  get parenthesized(): AnyIfConditionExpression {
    return this._parenthesized!;
  }
  set parenthesized(
    parenthesized: AnyIfConditionExpression | IfConditionExpressionProps,
  ) {
    if (this._parenthesized) this._parenthesized.parent = undefined;
    const built = fromProps(parenthesized);
    built.parent = this;
    this._parenthesized = built;
  }
  declare private _parenthesized?: AnyIfConditionExpression;

  constructor(
    defaults:
      | IfConditionParenthesizedProps
      | AnyIfConditionExpression
      | IfConditionExpressionProps,
  );
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfConditionParenthesized);
  constructor(
    defaults?: object,
    inner?: sassInternal.IfConditionParenthesized,
  ) {
    if (defaults && !('parenthesized' in defaults)) {
      defaults = {parenthesized: defaults};
    }
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.parenthesized = convertIfConditionExpression(inner.expression);
    }
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfConditionParenthesizedProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'parenthesized']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['parenthesized'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      '(' +
      (this.raws.afterOpen ?? '') +
      this.parenthesized +
      (this.raws.beforeClose ?? '') +
      ')'
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyIfConditionExpression> {
    return [this.parenthesized];
  }
}
