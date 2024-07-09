// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {convertExpression} from './expression/convert';
import {fromProps} from './expression/from-props';
import {Expression, ExpressionProps} from './expression';
import {LazySource} from './lazy-source';
import {Node} from './node';
import type * as sassInternal from './sass-internal';
import * as utils from './utils';

/**
 * The type of new nodes that can be passed into an interpolation.
 *
 * @category Expression
 */
export type NewNodeForInterpolation =
  | Interpolation
  | Interpolation[]
  | Expression
  | Expression[]
  | ExpressionProps
  | ExpressionProps[]
  | string
  | string[]
  | undefined;

/**
 * The initializer properties for {@link Interpolation}
 *
 * @category Expression
 */
export interface InterpolationProps {
  nodes: NewNodeForInterpolation[];
  raws?: InterpolationRaws;
}

/**
 * Raws indicating how to precisely serialize an {@link Interpolation} node.
 *
 * @category Expression
 */
export interface InterpolationRaws {
  /**
   * The text written in the stylesheet for the plain-text portions of the
   * interpolation, without any interpretation of escape sequences.
   *
   * `raw` is the value of the raw itself, and `value` is the parsed value
   * that's required to be in the interpolation in order for this raw to be used.
   *
   * Any indices for which {@link Interpolation.nodes} doesn't contain a string
   * are ignored.
   */
  text?: Array<{raw: string; value: string} | undefined>;

  /**
   * The whitespace before and after each interpolated expression.
   *
   * Any indices for which {@link Interpolation.nodes} doesn't contain an
   * expression are ignored.
   */
  expressions?: Array<{before?: string; after?: string} | undefined>;
}

// Note: unlike the Dart Sass interpolation class, this does *not* guarantee
// that there will be no adjacent strings. Doing so for user modification would
// cause any active iterators to skip the merged string, and the collapsing
// doesn't provide a tremendous amount of user benefit.

/**
 * Sass text that can contian expressions interpolated within it.
 *
 * This is not itself an expression. Instead, it's used as a field of
 * expressions and statements, and acts as a container for further expressions.
 *
 * @category Expression
 */
export class Interpolation extends Node {
  readonly sassType = 'interpolation' as const;
  declare raws: InterpolationRaws;

  /**
   * An array containing the contents of the interpolation.
   *
   * Strings in this array represent the raw text in which interpolation (might)
   * appear, and expressions represent the interpolated Sass expressions.
   *
   * This shouldn't be modified directly; instead, the various methods defined
   * in {@link Interpolation} should be used to modify it.
   */
  get nodes(): ReadonlyArray<string | Expression> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<string | Expression>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private _nodes?: Array<string | Expression>;

  /** Returns whether this contains no interpolated expressions. */
  get isPlain(): boolean {
    return this.asPlain !== null;
  }

  /**
   * If this contains no interpolated expressions, returns its text contents.
   * Otherwise, returns `null`.
   */
  get asPlain(): string | null {
    if (this.nodes.length === 0) return '';
    if (this.nodes.length !== 1) return null;
    if (typeof this.nodes[0] !== 'string') return null;
    return this.nodes[0] as string;
  }

  /**
   * Iterators that are currently active within this interpolation. Their
   * indices refer to the last position that has already been sent to the
   * callback, and are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: InterpolationProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.Interpolation);
  constructor(defaults?: object, inner?: sassInternal.Interpolation) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      // TODO: set lazy raws here to use when stringifying
      this._nodes = [];
      for (const child of inner.contents) {
        this.append(
          typeof child === 'string' ? child : convertExpression(child)
        );
      }
    }
    if (this._nodes === undefined) this._nodes = [];
  }

  clone(overrides?: Partial<InterpolationProps>): this {
    return utils.cloneNode(this, overrides, ['nodes', 'raws']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  /**
   * Inserts new nodes at the end of this interpolation.
   *
   * Note: unlike PostCSS's [`Container.append()`], this treats strings as raw
   * text rather than parsing them into new nodes.
   *
   * [`Container.append()`]: https://postcss.org/api/#container-append
   */
  append(...nodes: NewNodeForInterpolation[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

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
    callback: (node: string | Expression, index: number) => false | void
  ): false | undefined {
    const iterator = {index: 0};
    this.#iterators.push(iterator);

    try {
      while (iterator.index < this.nodes.length) {
        const result = callback(this.nodes[iterator.index], iterator.index);
        if (result === false) return false;
        iterator.index += 1;
      }
      return undefined;
    } finally {
      this.#iterators.splice(this.#iterators.indexOf(iterator), 1);
    }
  }

  /**
   * Returns `true` if {@link condition} returns `true` for all of the
   * container’s children.
   */
  every(
    condition: (
      node: string | Expression,
      index: number,
      nodes: ReadonlyArray<string | Expression>
    ) => boolean
  ): boolean {
    return this.nodes.every(condition);
  }

  /**
   * Returns the first index of {@link child} in {@link nodes}.
   *
   * If {@link child} is a number, returns it as-is.
   */
  index(child: string | Expression | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  /**
   * Inserts {@link newNode} immediately after the first occurance of
   * {@link oldNode} in {@link nodes}.
   *
   * If {@link oldNode} is a number, inserts {@link newNode} immediately after
   * that index instead.
   */
  insertAfter(
    oldNode: string | Expression | number,
    newNode: NewNodeForInterpolation
  ): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(oldNode);
    const normalized = this._normalize(newNode);
    this._nodes!.splice(index + 1, 0, ...normalized);

    for (const iterator of this.#iterators) {
      if (iterator.index > index) iterator.index += normalized.length;
    }

    return this;
  }

  /**
   * Inserts {@link newNode} immediately before the first occurance of
   * {@link oldNode} in {@link nodes}.
   *
   * If {@link oldNode} is a number, inserts {@link newNode} at that index
   * instead.
   */
  insertBefore(
    oldNode: string | Expression | number,
    newNode: NewNodeForInterpolation
  ): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(oldNode);
    const normalized = this._normalize(newNode);
    this._nodes!.splice(index, 0, ...normalized);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index += normalized.length;
    }

    return this;
  }

  /** Inserts {@link nodes} at the beginning of the interpolation. */
  prepend(...nodes: NewNodeForInterpolation[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  /** Adds {@link child} to the end of this interpolation. */
  push(child: string | Expression): this {
    return this.append(child);
  }

  /**
   * Removes all {@link nodes} from this interpolation and cleans their {@link
   * Node.parent} properties.
   */
  removeAll(): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    for (const node of this.nodes) {
      if (typeof node !== 'string') node.parent = undefined;
    }
    this._nodes!.length = 0;
    return this;
  }

  /**
   * Removes the first occurance of {@link child} from the container and cleans
   * the parent properties from the node and its children.
   *
   * If {@link child} is a number, removes the child at that index.
   */
  removeChild(child: string | Expression | number): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(child);
    if (typeof child === 'object') child.parent = undefined;
    this._nodes!.splice(index, 1);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index--;
    }

    return this;
  }

  /**
   * Returns `true` if {@link condition} returns `true` for (at least) one of
   * the container’s children.
   */
  some(
    condition: (
      node: string | Expression,
      index: number,
      nodes: ReadonlyArray<string | Expression>
    ) => boolean
  ): boolean {
    return this.nodes.some(condition);
  }

  /** The first node in {@link nodes}. */
  get first(): string | Expression | undefined {
    return this.nodes[0];
  }

  /**
   * The container’s last child.
   *
   * ```js
   * rule.last === rule.nodes[rule.nodes.length - 1]
   * ```
   */
  get last(): string | Expression | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';

    const rawText = this.raws.text;
    const rawExpressions = this.raws.expressions;
    for (let i = 0; i < this.nodes.length; i++) {
      const element = this.nodes[i];
      if (typeof element === 'string') {
        const raw = rawText?.[i];
        result += raw?.value === element ? raw.raw : element;
      } else {
        const raw = rawExpressions?.[i];
        result +=
          '#{' + (raw?.before ?? '') + element + (raw?.after ?? '') + '}';
      }
    }
    return result;
  }

  /**
   * Normalizes the many types of node that can be used with Interpolation
   * methods.
   */
  private _normalize(nodes: NewNodeForInterpolation): (Expression | string)[] {
    const result: Array<string | Expression> = [];
    for (const node of Array.isArray(nodes) ? nodes : [nodes]) {
      if (node === undefined) {
        continue;
      } else if (typeof node === 'string') {
        if (node.length === 0) continue;
        result.push(node);
      } else if ('sassType' in node) {
        if (node.sassType === 'interpolation') {
          for (const subnode of node.nodes) {
            if (typeof subnode === 'string') {
              if (node.nodes.length === 0) continue;
              result.push(subnode);
            } else {
              subnode.parent = this;
              result.push(subnode);
            }
          }
          node._nodes!.length = 0;
        } else {
          node.parent = this;
          result.push(node);
        }
      } else {
        const constructed = fromProps(node);
        constructed.parent = this;
        result.push(constructed);
      }
    }
    return result;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: NewNodeForInterpolation[]
  ): (Expression | string)[] {
    const result: Array<string | Expression> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return this.nodes.filter(
      (node): node is Expression => typeof node !== 'string'
    );
  }
}
