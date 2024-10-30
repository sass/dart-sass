// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws as PostcssAtRuleRaws} from 'postcss/lib/at-rule';

import {convertExpression} from '../expression/convert';
import {Expression, ExpressionProps} from '../expression';
import {fromProps} from '../expression/from-props';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Statement, StatementWithChildren} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link WarnRule}.
 *
 * @category Statement
 */
export type WarnRuleRaws = Pick<
  PostcssAtRuleRaws,
  'afterName' | 'before' | 'between'
>;

/**
 * The initializer properties for {@link WarnRule}.
 *
 * @category Statement
 */
export type WarnRuleProps = postcss.NodeProps & {
  raws?: WarnRuleRaws;
  warnExpression: Expression | ExpressionProps;
};

/**
 * A `@warn` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class WarnRule
  extends _AtRule<Partial<WarnRuleProps>>
  implements Statement
{
  readonly sassType = 'warn-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: WarnRuleRaws;
  declare readonly nodes: undefined;

  get name(): string {
    return 'warn';
  }
  set name(value: string) {
    throw new Error("WarnRule.name can't be overwritten.");
  }

  get params(): string {
    return this.warnExpression.toString();
  }
  set params(value: string | number | undefined) {
    this.warnExpression = {text: value?.toString() ?? ''};
  }

  /** The expresison whose value is emitted when the warn rule is executed. */
  get warnExpression(): Expression {
    return this._warnExpression!;
  }
  set warnExpression(warnExpression: Expression | ExpressionProps) {
    if (this._warnExpression) this._warnExpression.parent = undefined;
    if (!('sassType' in warnExpression)) {
      warnExpression = fromProps(warnExpression);
    }
    if (warnExpression) warnExpression.parent = this;
    this._warnExpression = warnExpression;
  }
  private _warnExpression?: Expression;

  constructor(defaults: WarnRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.WarnRule);
  constructor(defaults?: WarnRuleProps, inner?: sassInternal.WarnRule) {
    super(defaults as unknown as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.warnExpression = convertExpression(inner.expression);
    }
  }

  clone(overrides?: Partial<WarnRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['raws', 'warnExpression'],
      [{name: 'params', explicitUndefined: true}],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'warnExpression', 'params', 'nodes'],
      inputs,
    );
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.warnExpression];
  }
}

interceptIsClean(WarnRule);
