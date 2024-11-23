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
 * The set of raws supported by {@link MixinRule}.
 *
 * @category Statement
 */
export interface MixinRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /**
   * The mixin's name.
   *
   * This may be different than {@link Mixin.mixinName} if the name contains
   * escape codes or underscores.
   */
  mixinName?: RawWithValue<string>;
}

/**
 * The initializer properties for {@link MixinRule}.
 *
 * @category Statement
 */
export type MixinRuleProps = ContainerProps & {
  raws?: MixinRuleRaws;
  mixinName: string;
  parameters?: ParameterList | ParameterListProps;
};

/**
 * A `@mixin` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class MixinRule
  extends _AtRule<Partial<MixinRuleProps>>
  implements Statement
{
  readonly sassType = 'mixin-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: MixinRuleRaws;
  declare nodes: ChildNode[];

  /**
   * The name of the mixin.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare mixinName: string;

  /** The parameters that this mixin takes. */
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
  private declare _parameters: ParameterList;

  get name(): string {
    return 'mixin';
  }
  set name(value: string) {
    throw new Error("MixinRule.name can't be overwritten.");
  }

  get params(): string {
    return (
      (this.raws.mixinName?.value === this.mixinName
        ? this.raws.mixinName!.raw
        : sassInternal.toCssIdentifier(this.mixinName)) + this.parameters
    );
  }
  set params(value: string | number | undefined) {
    throw new Error("MixinRule.params can't be overwritten.");
  }

  constructor(defaults: MixinRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.MixinRule);
  constructor(defaults?: MixinRuleProps, inner?: sassInternal.MixinRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      this.mixinName = inner.name;
      this.parameters = new ParameterList(undefined, inner.arguments);
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<MixinRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'mixinName',
      'parameters',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'mixinName', 'parameters', 'nodes'],
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

interceptIsClean(MixinRule);
