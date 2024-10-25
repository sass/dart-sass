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
 * The set of raws supported by {@link WhileRule}.
 *
 * @category Statement
 */
export type WhileRuleRaws = Omit<AtRuleRaws, 'params'>;

/**
 * The initializer properties for {@link WhileRule}.
 *
 * @category Statement
 */
export type WhileRuleProps = ContainerProps & {
  raws?: WhileRuleRaws;
  whileCondition: Expression | ExpressionProps;
};

/**
 * A `@while` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class WhileRule
  extends _AtRule<Partial<WhileRuleProps>>
  implements Statement
{
  readonly sassType = 'while-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: WhileRuleRaws;
  declare nodes: ChildNode[];

  get name(): string {
    return 'while';
  }
  set name(value: string) {
    throw new Error("WhileRule.name can't be overwritten.");
  }

  get params(): string {
    return this.whileCondition.toString();
  }
  set params(value: string | number | undefined) {
    throw new Error("WhileRule.params can't be overwritten.");
  }

  /** The expresison whose value is emitted when the while rule is executed. */
  get whileCondition(): Expression {
    return this._whileCondition!;
  }
  set whileCondition(whileCondition: Expression | ExpressionProps) {
    if (this._whileCondition) this._whileCondition.parent = undefined;
    if (!('sassType' in whileCondition)) {
      whileCondition = fromProps(whileCondition);
    }
    if (whileCondition) whileCondition.parent = this;
    this._whileCondition = whileCondition;
  }
  private _whileCondition?: Expression;

  constructor(defaults: WhileRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.WhileRule);
  constructor(defaults?: WhileRuleProps, inner?: sassInternal.WhileRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      this.whileCondition = convertExpression(inner.condition);
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<WhileRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['raws', 'whileCondition']
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'whileCondition', 'params', 'nodes'],
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
    return [this.whileCondition];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(WhileRule);
