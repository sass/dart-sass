// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import {ContainerWithChildren} from 'postcss/lib/container';

import {Rule} from './rule';
import {Root} from './root';
import {AnyDeclaration, AtRule, ChildNode, Comment, NewNode} from '.';

/**
 * A fake intermediate class to convince TypeScript to use Sass types for
 * various upstream methods.
 *
 * @hidden
 */
export class _Declaration<Props> extends postcss.Declaration {
  // Override the PostCSS types to constrain them to Sass types only.
  // Unfortunately, there's no way to abstract this out, because anything
  // mixin-like returns an intersection type which doesn't actually override
  // parent methods. See microsoft/TypeScript#59394.

  after(newNode: NewNode): this;
  assign(overrides: Partial<Props>): this;
  before(newNode: NewNode): this;
  cloneAfter(overrides?: Partial<Props>): this;
  cloneBefore(overrides?: Partial<Props>): this;
  next(): ChildNode | undefined;
  prev(): ChildNode | undefined;
  replaceWith(...nodes: NewNode[]): this;
  root(): Root;
}

// This functionally extends *both* `_Declaration<Props>` and
// `postcss.Container`, but because TypeScript doesn't support proper multiple
// inheritance and the latter has protected properties we need to explicitly
// extend it.

/**
 * A fake intermediate class to convince TypeScript to use Sass types for
 * various upstream methods.
 *
 * @hidden
 */
export class _DeclarationWithChildren<Props>
  extends postcss.Container
  implements _Declaration<Props>
{
  declare parent: ContainerWithChildren | undefined;
  declare type: 'decl';

  get prop(): string;
  get value(): string;
  get important(): boolean;
  get variable(): boolean;

  after(newNode: NewNode): this;
  assign(overrides: Partial<Props>): this;
  before(newNode: NewNode): this;
  clone(overrides?: Partial<Props>): this;
  cloneAfter(overrides?: Partial<Props>): this;
  cloneBefore(overrides?: Partial<Props>): this;
  next(): ChildNode | undefined;
  prev(): ChildNode | undefined;
  replaceWith(...nodes: NewNode[]): this;
  root(): Root;

  append(...nodes: NewNode[]): this;
  each(
    callback: (node: ChildNode, index: number) => false | void,
  ): false | undefined;
  every(
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean,
  ): boolean;
  index(child: postcss.ChildNode | number): number;
  insertAfter(oldNode: postcss.ChildNode | number, newNode: NewNode): this;
  insertBefore(oldNode: postcss.ChildNode | number, newNode: NewNode): this;
  prepend(...nodes: NewNode[]): this;
  push(child: ChildNode): this;
  removeAll(): this;
  removeChild(child: postcss.ChildNode | number): this;
  replaceValues(
    pattern: RegExp | string,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    replaced: {(substring: string, ...args: any[]): string} | string,
  ): this;
  replaceValues(
    pattern: RegExp | string,
    options: {fast?: string; props?: readonly string[]},
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    replaced: {(substring: string, ...args: any[]): string} | string,
  ): this;
  some(
    condition: (node: ChildNode, index: number, nodes: ChildNode[]) => boolean,
  ): boolean;
  walk(
    callback: (node: ChildNode, index: number) => false | void,
  ): false | undefined;
  walkAtRules(
    nameFilter: RegExp | string,
    callback: (atRule: AtRule, index: number) => false | void,
  ): false | undefined;
  walkAtRules(
    callback: (atRule: AtRule, index: number) => false | void,
  ): false | undefined;
  walkComments(
    callback: (comment: Comment, indexed: number) => false | void,
  ): false | undefined;
  walkComments(
    callback: (comment: Comment, indexed: number) => false | void,
  ): false | undefined;
  walkDecls(
    propFilter: RegExp | string,
    callback: (decl: AnyDeclaration, index: number) => false | void,
  ): false | undefined;
  walkDecls(
    callback: (decl: AnyDeclaration, index: number) => false | void,
  ): false | undefined;
  walkRules(
    selectorFilter: RegExp | string,
    callback: (rule: Rule, index: number) => false | void,
  ): false | undefined;
  walkRules(
    callback: (rule: Rule, index: number) => false | void,
  ): false | undefined;
  get first(): ChildNode | undefined;
  get last(): ChildNode | undefined;
}
