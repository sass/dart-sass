// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Rule} from './rule';
import {Root, RootProps} from './root';
import {AtRule, ChildNode, ChildProps, Comment, Declaration, NewNode} from '.';

/**
 * A fake intermediate class to convince TypeScript to use Sass types for
 * various upstream methods.
 *
 * @hidden
 */
export class _Root extends postcss.Root {
  declare nodes: ChildNode[];

  // Override the PostCSS container types to constrain them to Sass types only.
  // Unfortunately, there's no way to abstract this out, because anything
  // mixin-like returns an intersection type which doesn't actually override
  // parent methods. See microsoft/TypeScript#59394.

  after(newNode: NewNode): this;
  append(...nodes: NewNode[]): this;
  assign(overrides: Partial<RootProps>): this;
  before(newNode: NewNode): this;
  cloneAfter(overrides?: Partial<RootProps>): this;
  cloneBefore(overrides?: Partial<RootProps>): this;
  each(
    callback: (node: ChildNode, index: number) => false | void
  ): false | undefined;
  every(
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean
  ): boolean;
  index(child: ChildNode | number): number;
  insertAfter(oldNode: ChildNode | number, newNode: NewNode): this;
  insertBefore(oldNode: ChildNode | number, newNode: NewNode): this;
  next(): ChildNode | undefined;
  prepend(...nodes: NewNode[]): this;
  prev(): ChildNode | undefined;
  push(child: ChildNode): this;
  removeChild(child: ChildNode | number): this;
  replaceWith(
    ...nodes: (postcss.Node | postcss.Node[] | ChildProps | ChildProps[])[]
  ): this;
  root(): Root;
  some(
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean
  ): boolean;
  walk(
    callback: (node: ChildNode, index: number) => false | void
  ): false | undefined;
  walkAtRules(
    nameFilter: RegExp | string,
    callback: (atRule: AtRule, index: number) => false | void
  ): false | undefined;
  walkAtRules(
    callback: (atRule: AtRule, index: number) => false | void
  ): false | undefined;
  walkComments(
    callback: (comment: Comment, indexed: number) => false | void
  ): false | undefined;
  walkComments(
    callback: (comment: Comment, indexed: number) => false | void
  ): false | undefined;
  walkDecls(
    propFilter: RegExp | string,
    callback: (decl: Declaration, index: number) => false | void
  ): false | undefined;
  walkDecls(
    callback: (decl: Declaration, index: number) => false | void
  ): false | undefined;
  walkRules(
    selectorFilter: RegExp | string,
    callback: (rule: Rule, index: number) => false | void
  ): false | undefined;
  walkRules(
    callback: (rule: Rule, index: number) => false | void
  ): false | undefined;
  get first(): ChildNode | undefined;
  get last(): ChildNode | undefined;
}
