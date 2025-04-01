// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {convertExpression} from '../expression/convert';
import {AnyExpression, ExpressionProps} from '../expression';
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
 * The set of raws supported by {@link IfRule}.
 *
 * @category Statement
 */
export type IfRuleRaws = Omit<AtRuleRaws, 'params'>;

/**
 * The initializer properties for {@link IfRule}.
 *
 * @category Statement
 */
export type IfRuleProps = ContainerProps & {
  raws?: IfRuleRaws;
  ifCondition: AnyExpression | ExpressionProps;
};

/**
 * A `@if` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class IfRule extends _AtRule<Partial<IfRuleProps>> implements Statement {
  readonly sassType = 'if-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: IfRuleRaws;
  declare nodes: ChildNode[];

  get name(): string {
    return 'if';
  }
  set name(value: string) {
    throw new Error("IfRule.name can't be overwritten.");
  }

  get params(): string {
    return this.ifCondition.toString();
  }
  set params(value: string | number | undefined) {
    throw new Error("IfRule.params can't be overwritten.");
  }

  /** The expression whose value determines whether to execute this block. */
  get ifCondition(): AnyExpression {
    return this._ifCondition!;
  }
  set ifCondition(ifCondition: AnyExpression | ExpressionProps) {
    if (this._ifCondition) this._ifCondition.parent = undefined;
    const built =
      'sassType' in ifCondition ? ifCondition : fromProps(ifCondition);
    built.parent = this;
    this._ifCondition = built;
  }
  private declare _ifCondition?: AnyExpression;

  constructor(defaults: IfRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfRule);
  constructor(defaults?: IfRuleProps, inner?: sassInternal.IfRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      this.ifCondition = convertExpression(inner.clauses[0].expression);
      appendInternalChildren(this, inner.clauses[0].children);
    }
  }

  clone(overrides?: Partial<IfRuleProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'ifCondition']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'ifCondition', 'params', 'nodes'],
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
  get nonStatementChildren(): ReadonlyArray<AnyExpression> {
    return [this.ifCondition];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(IfRule);
