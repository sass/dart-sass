// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// Used in TypeDoc
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import type * as postcss from 'postcss';

// Used in TypeDoc
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import type {Interpolation} from './interpolation';

/**
 * A Sass AST container. While this tries to maintain the general shape of the
 * {@link postcss.Container} interface, it's more broadly used to contain
 * other node types (and even strings in the case of {@link Interpolation}.
 *
 * @typeParam Child - The type of child nodes that this container can contain.
 * @typeParam NewChild - The type of values that can be passed in to create one
 *   or more new child nodes for this container.
 */
export interface Container<Child, NewChild> {
  /**
   * The nodes in this container.
   *
   * This shouldn't be modified directly; instead, the various methods defined
   * in {@link Container} should be used to modify it.
   */
  get nodes(): ReadonlyArray<Child>;

  /** Inserts new nodes at the end of this interpolation. */
  append(...nodes: NewChild[]): this;

  /**
   * Iterates through {@link nodes}, calling `callback` for each child.
   *
   * Returning `false` in the callback will break iteration.
   *
   * Unlike a `for` loop or `Array#forEach`, this iterator is safe to use while
   * modifying the interpolation's children.
   *
   * @param callback The iterator callback, which is passed each child
   * @return Returns `false` if any call to `callback` returned false
   */
  each(
    callback: (node: Child, index: number) => false | void,
  ): false | undefined;

  /**
   * Returns `true` if {@link condition} returns `true` for all of the
   * container’s children.
   */
  every(
    condition: (
      node: Child,
      index: number,
      nodes: ReadonlyArray<Child>,
    ) => boolean,
  ): boolean;

  /**
   * Returns the first index of {@link child} in {@link nodes}.
   *
   * If {@link child} is a number, returns it as-is.
   */
  index(child: Child | number): number;

  /**
   * Inserts {@link newNode} immediately after the first occurance of
   * {@link oldNode} in {@link nodes}.
   *
   * If {@link oldNode} is a number, inserts {@link newNode} immediately after
   * that index instead.
   */
  insertAfter(oldNode: Child | number, newNode: NewChild): this;

  /**
   * Inserts {@link newNode} immediately before the first occurance of
   * {@link oldNode} in {@link nodes}.
   *
   * If {@link oldNode} is a number, inserts {@link newNode} at that index
   * instead.
   */
  insertBefore(oldNode: Child | number, newNode: NewChild): this;

  /** Inserts {@link nodes} at the beginning of the container. */
  prepend(...nodes: NewChild[]): this;

  /** Adds {@link child} to the end of this interpolation. */
  push(child: Child): this;

  /**
   * Removes all {@link nodes} from this container and cleans their {@link
   * Node.parent} properties.
   */
  removeAll(): this;

  /**
   * Removes the first occurance of {@link child} from the container and cleans
   * the parent properties from the node and its children.
   *
   * If {@link child} is a number, removes the child at that index.
   */
  removeChild(child: Child | number): this;

  /**
   * Returns `true` if {@link condition} returns `true` for (at least) one of
   * the container’s children.
   */
  some(
    condition: (
      node: Child,
      index: number,
      nodes: ReadonlyArray<Child>,
    ) => boolean,
  ): boolean;

  /** The first node in {@link nodes}. */
  get first(): Child | undefined;

  /**
   * The container’s last child.
   *
   * ```js
   * rule.last === rule.nodes[rule.nodes.length - 1]
   * ```
   */
  get last(): Child | undefined;
}
