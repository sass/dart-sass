// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {LazySource} from '../lazy-source';
import {ParameterList, ParameterListProps} from '../parameter-list';
import {RawWithValue} from '../raw-with-value';
import * as sassInternal from '../sass-internal';
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
 * The set of raws supported by {@link FunctionRule}.
 *
 * @category Statement
 */
export interface FunctionRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /**
   * The function's name.
   *
   * This may be different than {@link FunctionRule.functionName} if the name
   * contains escape codes or underscores.
   */
  functionName?: RawWithValue<string>;
}

/**
 * The initializer properties for {@link FunctionRule}.
 *
 * @category Statement
 */
export type FunctionRuleProps = ContainerProps & {
  raws?: FunctionRuleRaws;
  functionName: string;
  parameters?: ParameterList | ParameterListProps;
};

/**
 * A `@function` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class FunctionRule
  extends _AtRule<Partial<FunctionRuleProps>>
  implements Statement
{
  readonly sassType = 'function-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: FunctionRuleRaws;
  declare nodes: ChildNode[];

  /**
   * The name of the function.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare functionName: string;

  /** The parameters that this function takes. */
  get parameters(): ParameterList {
    return this._parameters!;
  }
  set parameters(parameters: ParameterList | ParameterListProps) {
    if (this._parameters) {
      this._parameters.parent = undefined;
    }
    this._parameters =
      'sassType' in parameters ? parameters : new ParameterList(parameters);
    this._parameters.parent = this;
  }
  declare private _parameters: ParameterList;

  get name(): string {
    return 'function';
  }
  set name(value: string) {
    throw new Error("FunctionRule.name can't be overwritten.");
  }

  get params(): string {
    return (
      (this.raws.functionName?.value === this.functionName
        ? this.raws.functionName!.raw
        : sassInternal.toCssIdentifier(this.functionName)) + this.parameters
    );
  }
  set params(value: string | number | undefined) {
    throw new Error("FunctionRule.params can't be overwritten.");
  }

  constructor(defaults: FunctionRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.FunctionRule);
  constructor(defaults?: FunctionRuleProps, inner?: sassInternal.FunctionRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      this.functionName = inner.name;
      this.parameters = new ParameterList(undefined, inner.parameters);
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<FunctionRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'functionName',
      'parameters',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'params', 'functionName', 'parameters', 'nodes'],
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
  get nonStatementChildren(): ReadonlyArray<ParameterList> {
    return [this.parameters];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(FunctionRule);
