// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {convertExpression} from '../expression/convert';
import {Expression, ExpressionProps} from '../expression';
import {fromProps} from '../expression/from-props';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {
  ChildNode,
  ContainerProps,
  NewNode,
  Statement,
  StatementWithChildren,
  appendInternalChildren,
  normalize,
} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link EachRule}.
 *
 * @category Statement
 */
export interface EachRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /**
   * The whitespace and commas after each variable in
   * {@link EachRule.variables}.
   *
   * The element at index `i` is included after the variable at index `i`. Any
   * elements beyond `variables.length` are ignored.
   */
  afterVariables?: string[];

  /** The whitespace between `in` and {@link EachRule.eachExpression}. */
  afterIn?: string;
}

/**
 * The initializer properties for {@link EachRule}.
 *
 * @category Statement
 */
export type EachRuleProps = ContainerProps & {
  raws?: EachRuleRaws;
  variables: string[];
  eachExpression: Expression | ExpressionProps;
};

/**
 * An `@each` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class EachRule
  extends _AtRule<Partial<EachRuleProps>>
  implements Statement
{
  readonly sassType = 'each-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: EachRuleRaws;
  declare nodes: ChildNode[];

  /** The variable names assigned for each iteration, without `"$"`. */
  declare variables: string[];

  get name(): string {
    return 'each';
  }
  set name(value: string) {
    throw new Error("EachRule.name can't be overwritten.");
  }

  get params(): string {
    let result = '';
    for (let i = 0; i < this.variables.length; i++) {
      result +=
        '$' +
        this.variables[i] +
        (this.raws?.afterVariables?.[i] ??
          (i === this.variables.length - 1 ? ' ' : ', '));
    }
    return `${result}in${this.raws.afterIn ?? ' '}${this.eachExpression}`;
  }
  set params(value: string | number | undefined) {
    throw new Error("EachRule.params can't be overwritten.");
  }

  /** The expresison whose value is iterated over. */
  get eachExpression(): Expression {
    return this._eachExpression!;
  }
  set eachExpression(eachExpression: Expression | ExpressionProps) {
    if (this._eachExpression) this._eachExpression.parent = undefined;
    if (!('sassType' in eachExpression)) {
      eachExpression = fromProps(eachExpression);
    }
    if (eachExpression) eachExpression.parent = this;
    this._eachExpression = eachExpression;
  }
  private _eachExpression?: Expression;

  constructor(defaults: EachRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.EachRule);
  constructor(defaults?: EachRuleProps, inner?: sassInternal.EachRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      this.variables = [...inner.variables];
      this.eachExpression = convertExpression(inner.list);
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<EachRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'variables',
      'eachExpression',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'variables', 'eachExpression', 'params', 'nodes'],
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
    return [this.eachExpression];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(EachRule);
