// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {NodeProps} from '../../node';
import type * as sassInternal from '../../sass-internal';
import * as utils from '../../utils';
import {fromProps} from '../from-props';
import {AnyExpression, ExpressionProps} from '../index';
import {AnyIfConditionExpression, IfConditionExpression} from './index';
import {IfEntry} from '../if-entry';
import {convertExpression} from '../convert';
import {LazySource} from '../../lazy-source';

/**
 * The set of raws supported by {@link IfConditionSass}.
 *
 * @category Expression
 */
export interface IfConditionSassRaws {
  /** The whitespace after the opening parenthesis. */
  afterOpen?: string;

  /** The whitespace before the closing parenthesis. */
  beforeClose?: string;
}

/**
 * The initializer properties for {@link IfConditionSass} as an explicit object.
 *
 * @category Expression
 */
export interface IfConditionSassObjectProps extends NodeProps {
  raws?: IfConditionSassRaws;
  expression: AnyExpression | ExpressionProps;
}

/**
 * The initializer properties for {@link IfConditionExpression}.
 *
 * @category Expression
 */
export type IfConditionSassProps =
  | IfConditionSassObjectProps
  | AnyExpression
  | ExpressionProps;

/**
 * A `sass()` expression in an `if()` condition.
 *
 * @category Expression
 */
export class IfConditionSass extends IfConditionExpression {
  readonly sassType = 'if-condition-sass' as const;
  declare raws: IfConditionSassRaws;
  declare parent: IfEntry | AnyIfConditionExpression | undefined;

  /** The boolean expression. */
  get expression(): AnyExpression {
    return this._expression!;
  }
  set expression(expression: AnyExpression | ExpressionProps) {
    if (this._expression) this._expression.parent = undefined;
    const built = 'sassType' in expression ? expression : fromProps(expression);
    built.parent = this;
    this._expression = built;
  }
  private declare _expression?: AnyExpression;

  constructor(defaults: IfConditionSassProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfConditionSass);
  constructor(defaults?: object, inner?: sassInternal.IfConditionSass) {
    if (defaults && !('expression' in defaults)) {
      defaults = {expression: defaults};
    }
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.expression = convertExpression(inner.expression);
    }
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfConditionSassObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'expression']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['expression'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      'sass(' +
      (this.raws.afterOpen ?? '') +
      this.expression +
      (this.raws.beforeClose ?? '') +
      ')'
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyExpression> {
    return [this.expression];
  }
}
