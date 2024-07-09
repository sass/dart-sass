// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {RuleRaws as PostcssRuleRaws} from 'postcss/lib/rule';

import {Interpolation} from '../interpolation';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import {Root} from './root';
import * as utils from '../utils';
import {
  AtRule,
  ChildNode,
  ChildProps,
  Comment,
  ContainerProps,
  Declaration,
  NewNode,
  Statement,
  StatementWithChildren,
  appendInternalChildren,
  normalize,
} from '.';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by a style rule.
 *
 * Sass doesn't support PostCSS's `params` raws, since the selector is lexed and
 * made directly available to the caller.
 *
 * @category Statement
 */
export type RuleRaws = Omit<PostcssRuleRaws, 'selector'>;

/**
 * The initializer properties for {@link Rule}.
 *
 * @category Statement
 */
export type RuleProps = ContainerProps & {raws?: RuleRaws} & (
    | {selectorInterpolation: Interpolation | string}
    | {selector: string}
    | {selectors: string[]}
  );

/**
 * A style rule. Extends [`postcss.Rule`].
 *
 * [`postcss.Rule`]: https://postcss.org/api/#rule
 *
 * @category Statement
 */
export class Rule extends postcss.Rule implements Statement {
  readonly sassType = 'rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: RuleRaws;

  get selector(): string {
    return this.selectorInterpolation.toString();
  }
  set selector(value: string) {
    this.selectorInterpolation = value;
  }

  /** The interpolation that represents this rule's selector. */
  get selectorInterpolation(): Interpolation {
    return this._selectorInterpolation!;
  }
  set selectorInterpolation(selectorInterpolation: Interpolation | string) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._selectorInterpolation) {
      this._selectorInterpolation.parent = undefined;
    }
    if (typeof selectorInterpolation === 'string') {
      selectorInterpolation = new Interpolation({
        nodes: [selectorInterpolation],
      });
    }
    selectorInterpolation.parent = this;
    this._selectorInterpolation = selectorInterpolation;
  }
  private _selectorInterpolation?: Interpolation;

  constructor(defaults: RuleProps);
  constructor(_: undefined, inner: sassInternal.StyleRule);
  /** @hidden */
  constructor(defaults?: RuleProps, inner?: sassInternal.StyleRule) {
    // PostCSS claims that it requires either selector or selectors, but we
    // define the former as a getter instead.
    super(defaults as postcss.RuleProps);
    if (inner) {
      this.source = new LazySource(inner);
      this.selectorInterpolation = new Interpolation(undefined, inner.selector);
      appendInternalChildren(this, inner.children);
    }
  }

  // TODO: Once we make selector parsing available to JS, use it to override
  // selectors() and to provide access to parsed selectors if selector is plain
  // text.

  clone(overrides?: Partial<RuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['nodes', 'raws', 'selectorInterpolation'],
      ['selector', 'selectors']
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['selector', 'selectorInterpolation', 'nodes'],
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
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    return [this.selectorInterpolation];
  }

  // Override the PostCSS container types to constrain them to Sass types only.
  // Unfortunately, there's no way to abstract this out, because anything
  // mixin-like returns an intersection type which doesn't actually override
  // parent methods. See microsoft/TypeScript#59394.

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }

  declare nodes: ChildNode[];
  declare after: (newNode: NewNode) => this;
  declare append: (...nodes: NewNode[]) => this;
  declare assign: (overrides: Partial<RuleProps>) => this;
  declare before: (newNode: NewNode) => this;
  declare cloneAfter: (overrides?: Partial<RuleProps>) => this;
  declare cloneBefore: (overrides?: Partial<RuleProps>) => this;
  declare each: (
    callback: (node: ChildNode, index: number) => false | void
  ) => false | undefined;
  declare every: (
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean
  ) => boolean;
  declare index: (child: ChildNode | number) => number;
  declare insertAfter: (oldNode: ChildNode | number, newNode: NewNode) => this;
  declare insertBefore: (oldNode: ChildNode | number, newNode: NewNode) => this;
  declare next: () => ChildNode | undefined;
  declare prepend: (...nodes: NewNode[]) => this;
  declare prev: () => ChildNode | undefined;
  declare push: (child: ChildNode) => this;
  declare removeChild: (child: ChildNode | number) => this;
  declare replaceWith: (
    ...nodes: (postcss.Node | postcss.Node[] | ChildProps | ChildProps[])[]
  ) => this;
  declare root: () => Root;
  declare some: (
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean
  ) => boolean;
  declare walk: (
    callback: (node: ChildNode, index: number) => false | void
  ) => false | undefined;
  declare walkAtRules: {
    (
      nameFilter: RegExp | string,
      callback: (atRule: AtRule, index: number) => false | void
    ): false | undefined;
    (
      callback: (atRule: AtRule, index: number) => false | void
    ): false | undefined;
  };
  declare walkComments: {
    (
      callback: (comment: Comment, indexed: number) => false | void
    ): false | undefined;
    (
      callback: (comment: Comment, indexed: number) => false | void
    ): false | undefined;
  };
  declare walkDecls: {
    (
      propFilter: RegExp | string,
      callback: (decl: Declaration, index: number) => false | void
    ): false | undefined;
    (
      callback: (decl: Declaration, index: number) => false | void
    ): false | undefined;
  };
  declare walkRules: {
    (
      selectorFilter: RegExp | string,
      callback: (rule: Rule, index: number) => false | void
    ): false | undefined;
    (callback: (rule: Rule, index: number) => false | void): false | undefined;
  };
  get first(): ChildNode | undefined {
    return super.first as ChildNode | undefined;
  }
  get last(): ChildNode | undefined {
    return super.last as ChildNode | undefined;
  }
}

interceptIsClean(Rule);
