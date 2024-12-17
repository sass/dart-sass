// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {ArgumentList, ArgumentListProps} from '../argument-list';
import {LazySource} from '../lazy-source';
import {Node} from '../node';
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
 * The set of raws supported by {@link IncludeRule}.
 *
 * @category Statement
 */
export interface IncludeRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /**
   * The mixin's namespace.
   *
   * This may be different than {@link IncludeRule.namespace} if the name
   * contains escape codes or underscores.
   */
  namespace?: RawWithValue<string>;

  /**
   * The mixin's name.
   *
   * This may be different than {@link IncludeRule.includeName} if the name
   * contains escape codes or underscores.
   */
  includeName?: RawWithValue<string>;

  /**
   * Whether to include an empty argument list. If the argument list isn't
   * empty, this is ignored.
   */
  showArguments?: boolean;

  /**
   * The whitespace between the argument list and the `using` identifier.
   *
   * This is ignored if {@link IncludeRule.usingParameters} isn't defined.
   */
  afterArguments?: string;

  /**
   * The whitespace between the `using` identifier and the using parameters.
   *
   * This is ignored if {@link IncludeRule.usingParameters} isn't defined.
   */
  afterUsing?: string;
}

/**
 * The initializer properties for {@link IncludeRule}.
 *
 * @category Statement
 */
export type IncludeRuleProps = ContainerProps & {
  raws?: IncludeRuleRaws;
  includeName: string;
  arguments?: ArgumentList | ArgumentListProps;
  using?: ParameterList | ParameterListProps;
};

/**
 * An `@include` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class IncludeRule
  extends _AtRule<Partial<IncludeRuleProps>>
  implements Statement
{
  readonly sassType = 'include-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: IncludeRuleRaws;
  declare nodes: ChildNode[] | undefined;

  /**
   * The mixin's namespace.
   *
   * This is the parsed value, with escapes resolved to the characters they
   * represent.
   */
  declare namespace: string | undefined;

  /**
   * The name of the mixin being included.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare includeName: string;

  /** The arguments to pass to the mixin. */
  get arguments(): ArgumentList {
    return this._arguments!;
  }
  set arguments(args: ArgumentList | ArgumentListProps) {
    if (this._arguments) {
      this._arguments.parent = undefined;
    }
    this._arguments = 'sassType' in args ? args : new ArgumentList(args);
    this._arguments.parent = this;
  }
  private declare _arguments: ArgumentList;

  /** The parameters that the `@content` block takes. */
  get using(): ParameterList | undefined {
    return this._using;
  }
  set using(parameters: ParameterList | ParameterListProps | undefined) {
    if (this._using) {
      this._using.parent = undefined;
    }
    if (parameters) {
      this._using =
        'sassType' in parameters ? parameters : new ParameterList(parameters);
      this._using.parent = this;
    } else {
      this._using = undefined;
    }
  }
  private declare _using?: ParameterList;

  get name(): string {
    return 'include';
  }
  set name(value: string) {
    throw new Error("IncludeRule.name can't be overwritten.");
  }

  get params(): string {
    return (
      (this.namespace
        ? (this.raws.namespace?.value === this.namespace
            ? this.raws.namespace.raw
            : sassInternal.toCssIdentifier(this.namespace)) + '.'
        : '') +
      (this.raws.includeName?.value === this.includeName
        ? this.raws.includeName!.raw
        : sassInternal.toCssIdentifier(this.includeName)) +
      (!this.raws.showArguments && this.arguments.nodes.length === 0
        ? ''
        : this.arguments) +
      (this.using
        ? (this.raws.afterArguments ?? ' ') +
          'using' +
          (this.raws.afterUsing ?? ' ') +
          this.using
        : '')
    );
  }
  set params(value: string | number | undefined) {
    throw new Error("IncludeRule.params can't be overwritten.");
  }

  constructor(defaults: IncludeRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IncludeRule);
  constructor(defaults?: IncludeRuleProps, inner?: sassInternal.IncludeRule) {
    super(defaults as unknown as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.namespace = inner.namespace ?? undefined;
      this.includeName = inner.name;
      this.arguments = new ArgumentList(undefined, inner.arguments);
      if (inner.content) {
        if (inner.content.parameters.parameters.length > 0) {
          this.using = new ParameterList(undefined, inner.content.parameters);
        }
        this.nodes = [];
        appendInternalChildren(this, inner.content.children);
      }
    }
    this._arguments ??= new ArgumentList();
  }

  clone(overrides?: Partial<IncludeRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'namespace', explicitUndefined: true},
      'includeName',
      'arguments',
      {name: 'using', explicitUndefined: true},
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
        'params',
        'namespace',
        'includeName',
        'arguments',
        'using',
        'nodes',
      ],
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
  get nonStatementChildren(): ReadonlyArray<Node> {
    const result: Node[] = [this.arguments];
    if (this.using) result.push(this.using);
    return result;
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    this.nodes ??= [];
    return normalize(this as StatementWithChildren, node, sample);
  }
}

interceptIsClean(IncludeRule);
