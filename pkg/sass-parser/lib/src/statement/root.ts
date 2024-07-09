// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {RootRaws} from 'postcss/lib/root';

import * as sassParser from '../..';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
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
  appendInternalChildren,
  normalize,
} from '.';
import {Rule} from './rule';

export type {RootRaws} from 'postcss/lib/root';

/**
 * The initializer properties for {@link Root}.
 *
 * @category Statement
 */
export interface RootProps extends ContainerProps {
  raws?: RootRaws;
}

/**
 * The root node of a Sass stylesheet. Extends [`postcss.Root`].
 *
 * [`postcss.Root`]: https://postcss.org/api/#root
 *
 * @category Statement
 */
export class Root extends postcss.Root implements Statement {
  readonly sassType = 'root' as const;
  declare parent: undefined;
  declare raws: RootRaws;

  /** @hidden */
  readonly nonStatementChildren = [] as const;

  constructor(defaults?: RootProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.Stylesheet);
  constructor(defaults?: object, inner?: sassInternal.Stylesheet) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<RootProps>): this {
    return utils.cloneNode(this, overrides, ['nodes', 'raws']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify
  ): string {
    return super.toString(stringifier);
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
  declare assign: (overrides: Partial<RootProps>) => this;
  declare before: (newNode: NewNode) => this;
  declare cloneAfter: (overrides?: Partial<RootProps>) => this;
  declare cloneBefore: (overrides?: Partial<RootProps>) => this;
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
