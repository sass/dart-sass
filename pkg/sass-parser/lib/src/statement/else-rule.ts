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
 * The set of raws supported by {@link ElseRule}.
 *
 * @category Statement
 */
export interface ElseRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /**
   * The whitespace between `if` and {@link ElseRule.elseExpression}. Ignored if
   * `elseExpression` is undefined.
   */
  afterIf?: string;
}

/**
 * The initializer properties for {@link ElseRule}.
 *
 * @category Statement
 */
export type ElseRuleProps = ContainerProps & {
  raws?: ElseRuleRaws;
  elseCondition?: Expression | ExpressionProps;
};

/**
 * A `@else` or `@else if` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ElseRule
  extends _AtRule<Partial<ElseRuleProps>>
  implements Statement
{
  readonly sassType = 'else-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ElseRuleRaws;
  declare nodes: ChildNode[];

  get name(): string {
    return 'else';
  }
  set name(value: string) {
    throw new Error("ElseRule.name can't be overwritten.");
  }

  get params(): string {
    return this.elseCondition
      ? 'if' + (this.raws.afterIf ?? ' ') + this.elseCondition.toString()
      : '';
  }
  set params(value: string | number | undefined) {
    throw new Error("ElseRule.params can't be overwritten.");
  }

  /**
   * The expression whose value determines whether to evaluate the block. If
   * this isn't set, the block is evaluated unconditionally.
   */
  get elseCondition(): Expression | undefined {
    return this._elseCondition!;
  }
  set elseCondition(elseCondition: Expression | ExpressionProps | undefined) {
    if (this._elseCondition) this._elseCondition.parent = undefined;
    if (elseCondition) {
      if (!('sassType' in elseCondition)) {
        elseCondition = fromProps(elseCondition);
      }
      elseCondition.parent = this;
    }
    this._elseCondition = elseCondition;
  }
  private declare _elseCondition?: Expression;

  constructor(defaults?: ElseRuleProps);
  /** @hidden */
  constructor(
    _: undefined,
    inner: sassInternal.IfRule,
    clause: sassInternal.IfClause | sassInternal.ElseClause | null,
  );
  constructor(
    defaults?: ElseRuleProps,
    inner?: sassInternal.IfRule,
    clause?: sassInternal.IfClause | sassInternal.ElseClause | null,
  ) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      if ('expression' in clause!) {
        this.elseCondition = convertExpression(clause.expression);
      }
      appendInternalChildren(this, clause!.children);
    }
  }

  clone(overrides?: Partial<ElseRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'elseCondition', explicitUndefined: true},
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'elseCondition', 'params', 'nodes'],
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
    return this.elseCondition ? [this.elseCondition] : [];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(ElseRule);
