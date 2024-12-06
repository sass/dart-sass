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
 * The set of raws supported by {@link ReturnRule}.
 *
 * @category Statement
 */
export type ReturnRuleRaws = Pick<
  PostcssAtRuleRaws,
  'afterName' | 'before' | 'between'
>;

/**
 * The initializer properties for {@link ReturnRule}.
 *
 * @category Statement
 */
export type ReturnRuleProps = postcss.NodeProps & {
  raws?: ReturnRuleRaws;
  returnExpression: Expression | ExpressionProps;
};

/**
 * A `@return` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ReturnRule
  extends _AtRule<Partial<ReturnRuleProps>>
  implements Statement
{
  readonly sassType = 'return-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ReturnRuleRaws;
  declare readonly nodes: undefined;

  get name(): string {
    return 'return';
  }
  set name(value: string) {
    throw new Error("ReturnRule.name can't be overwritten.");
  }

  get params(): string {
    return this.returnExpression.toString();
  }
  set params(value: string | number | undefined) {
    this.returnExpression = {text: value?.toString() ?? ''};
  }

  /** The expresison whose value is emitted when the return rule is executed. */
  get returnExpression(): Expression {
    return this._returnExpression!;
  }
  set returnExpression(returnExpression: Expression | ExpressionProps) {
    if (this._returnExpression) this._returnExpression.parent = undefined;
    if (!('sassType' in returnExpression)) {
      returnExpression = fromProps(returnExpression);
    }
    if (returnExpression) returnExpression.parent = this;
    this._returnExpression = returnExpression;
  }
  declare _returnExpression?: Expression;

  constructor(defaults: ReturnRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ReturnRule);
  constructor(defaults?: ReturnRuleProps, inner?: sassInternal.ReturnRule) {
    super(defaults as unknown as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.returnExpression = convertExpression(inner.expression);
    }
  }

  clone(overrides?: Partial<ReturnRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['raws', 'returnExpression'],
      [{name: 'params', explicitUndefined: true}],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'returnExpression', 'params', 'nodes'],
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
    return [this.returnExpression];
  }
}

interceptIsClean(ReturnRule);
