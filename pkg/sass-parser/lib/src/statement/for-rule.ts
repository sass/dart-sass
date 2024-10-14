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
 * The set of raws supported by {@link ForRule}.
 *
 * @category Statement
 */
export interface ForRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /** The whitespace after {@link ForRule.variable}. */
  afterVariable?: string;

  /** The whitespace after a {@link ForRule}'s `from` keyword. */
  afterFrom?: string;

  /** The whitespace after {@link ForRule.fromExpression}. */
  afterFromExpression?: string;

  /** The whitespace after a {@link ForRule}'s `to` or `through` keyword. */
  afterTo?: string;
}

/**
 * The initializer properties for {@link ForRule}.
 *
 * @category Statement
 */
export type ForRuleProps = ContainerProps & {
  raws?: ForRuleRaws;
  variable: string;
  fromExpression: Expression | ExpressionProps;
  toExpression: Expression | ExpressionProps;
  to?: 'to' | 'through';
};

/**
 * A `@for` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ForRule
  extends _AtRule<Partial<ForRuleProps>>
  implements Statement
{
  readonly sassType = 'for-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ForRuleRaws;
  declare nodes: ChildNode[];

  /** The variabl names assigned for for iteration, without `"$"`. */
  declare variable: string;

  /**
   * The keyword that appears before {@link toExpression}.
   *
   * If this is `"to"`, the loop is exclusive; if it's `"through"`, the loop is
   * inclusive. It defaults to `"to"` when creating a new `ForRule`.
   */
  declare to: 'to' | 'through';

  get name(): string {
    return 'for';
  }
  set name(value: string) {
    throw new Error("ForRule.name can't be overwritten.");
  }

  get params(): string {
    return (
      `$${this.variable}${this.raws.afterVariable ?? ' '}from` +
      `${this.raws.afterFrom ?? ' '}${this.fromExpression}` +
      `${this.raws.afterFromExpression ?? ' '}${this.to}` +
      `${this.raws.afterTo ?? ' '}${this.toExpression}`
    );
  }
  set params(value: string | number | undefined) {
    throw new Error("ForRule.params can't be overwritten.");
  }

  /** The expresison whose value is the starting point of the iteration. */
  get fromExpression(): Expression {
    return this._fromExpression!;
  }
  set fromExpression(fromExpression: Expression | ExpressionProps) {
    if (this._fromExpression) this._fromExpression.parent = undefined;
    if (!('sassType' in fromExpression)) {
      fromExpression = fromProps(fromExpression);
    }
    if (fromExpression) fromExpression.parent = this;
    this._fromExpression = fromExpression;
  }
  private _fromExpression?: Expression;

  /** The expresison whose value is the ending point of the iteration. */
  get toExpression(): Expression {
    return this._toExpression!;
  }
  set toExpression(toExpression: Expression | ExpressionProps) {
    if (this._toExpression) this._toExpression.parent = undefined;
    if (!('sassType' in toExpression)) {
      toExpression = fromProps(toExpression);
    }
    if (toExpression) toExpression.parent = this;
    this._toExpression = toExpression;
  }
  private _toExpression?: Expression;

  constructor(defaults: ForRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ForRule);
  constructor(defaults?: ForRuleProps, inner?: sassInternal.ForRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      this.variable = inner.variable;
      this.to = inner.isExclusive ? 'to' : 'through';
      this.fromExpression = convertExpression(inner.from);
      this.toExpression = convertExpression(inner.to);
      appendInternalChildren(this, inner.children);
    }

    this.to ??= 'to';
  }

  clone(overrides?: Partial<ForRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'variable',
      'to',
      'fromExpression',
      'toExpression',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      [
        'name',
        'variable',
        'to',
        'fromExpression',
        'toExpression',
        'params',
        'nodes',
      ],
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
    return [this.fromExpression, this.toExpression];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(ForRule);
