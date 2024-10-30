// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Rule} from './rule';
import {Root} from './root';
import {AtRule, ChildNode, Comment, Declaration, NewNode} from '.';

/**
 * A fake intermediate class to convince TypeScript to use Sass types for
 * various upstream methods.
 *
 * @hidden
 */
export class _AtRule<Props> extends postcss.AtRule {
  // Override the PostCSS container types to constrain them to Sass types only.
  // Unfortunately, there's no way to abstract this out, because anything
  // mixin-like returns an intersection type which doesn't actually override
  // parent methods. See microsoft/TypeScript#59394.

  after(newNode: NewNode): this;
  append(...nodes: NewNode[]): this;
  assign(overrides: Partial<Props>): this;
  before(newNode: NewNode): this;
  cloneAfter(overrides?: Partial<Props>): this;
  cloneBefore(overrides?: Partial<Props>): this;
  each(
    callback: (node: ChildNode, index: number) => false | void
  ): false | undefined;
  every(
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean
  ): boolean;
  insertAfter(oldNode: postcss.ChildNode | number, newNode: NewNode): this;
  insertBefore(oldNode: postcss.ChildNode | number, newNode: NewNode): this;
  next(): ChildNode | undefined;
  prepend(...nodes: NewNode[]): this;
  prev(): ChildNode | undefined;
  replaceWith(...nodes: NewNode[]): this;
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
