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
 * The set of raws supported by {@link ErrorRule}.
 *
 * @category Statement
 */
export type ErrorRuleRaws = Pick<
  PostcssAtRuleRaws,
  'afterName' | 'before' | 'between'
>;

/**
 * The initializer properties for {@link ErrorRule}.
 *
 * @category Statement
 */
export type ErrorRuleProps = postcss.NodeProps & {
  raws?: ErrorRuleRaws;
  errorExpression: Expression | ExpressionProps;
};

/**
 * An `@error` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ErrorRule
  extends _AtRule<Partial<ErrorRuleProps>>
  implements Statement
{
  readonly sassType = 'error-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ErrorRuleRaws;
  declare readonly nodes: undefined;

  get name(): string {
    return 'error';
  }
  set name(value: string) {
    throw new Error("ErrorRule.name can't be overwritten.");
  }

  get params(): string {
    return this.errorExpression.toString();
  }
  set params(value: string | number | undefined) {
    this.errorExpression = {text: value?.toString() ?? ''};
  }

  /** The expresison whose value is thrown when the error rule is executed. */
  get errorExpression(): Expression {
    return this._errorExpression!;
  }
  set errorExpression(errorExpression: Expression | ExpressionProps) {
    if (this._errorExpression) this._errorExpression.parent = undefined;
    if (!('sassType' in errorExpression)) {
      errorExpression = fromProps(errorExpression);
    }
    if (errorExpression) errorExpression.parent = this;
    this._errorExpression = errorExpression;
  }
  private _errorExpression?: Expression;

  constructor(defaults: ErrorRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ErrorRule);
  constructor(defaults?: ErrorRuleProps, inner?: sassInternal.ErrorRule) {
    super(defaults as unknown as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.errorExpression = convertExpression(inner.expression);
    }
  }

  clone(overrides?: Partial<ErrorRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['raws', 'errorExpression'],
      [{name: 'params', explicitUndefined: true}]
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'errorExpression', 'params', 'nodes'],
      inputs
    );
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.errorExpression];
  }
}

interceptIsClean(ErrorRule);
