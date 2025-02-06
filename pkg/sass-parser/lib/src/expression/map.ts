// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Container} from '../container';
import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression, ExpressionProps} from '.';
import {convertExpression} from './convert';
import {fromProps} from './from-props';

/**
 * The initializer properties for {@link MapExpression}.
 *
 * @category Expression
 */
export interface MapExpressionProps extends NodeProps {
  raws?: MapExpressionRaws;
  nodes: Array<[Expression | ExpressionProps, Expression | ExpressionProps]>;
}

// TODO: Parse strings.
/**
 * The type of new node pairs that can be passed into a map expression.
 *
 * @category Expression
 */
export type NewNodeForMapExpression =
  | [Expression, Expression]
  | ReadonlyArray<[Expression, Expression]>
  | [ExpressionProps, ExpressionProps]
  | ReadonlyArray<[ExpressionProps, ExpressionProps]>
  | undefined;

/**
 * Raws indicating how to precisely serialize a {@link MapExpression}.
 *
 * @category Expression
 */
export interface MapExpressionRaws {
  /**
   * The whitespace between the opening parenthesis and the first expression.
   */
  afterOpen?: string;

  /**
   * The whitespace between the last comma and the closing bracket.
   *
   * This is only set automatically for maps with trailing commas.
   */
  beforeClose?: string;

  /**
   * Whether this map has a trailing comma.
   *
   * Ignored if the expression has zero elements.
   */
  trailingComma?: boolean;

  /** The whitespace for each pair in the map. */
  pairs?: Array<MapExpressionPairRaws | undefined>;
}

/**
 * Raws indicating how to precisely serialize a single key/value pair in a
 * {@link MapExpression}.
 *
 * @category Expression
 */
export interface MapExpressionPairRaws {
  /** The whitespace before the pair's key. */
  before?: string;

  /** The text (including the colon) between the pair's key and value. */
  between?: string;

  /** The whitespace after the pair's value and before the comma. */
  after?: string;
}

/**
 * An expression representing a map literal in Sass.
 *
 * @category Expression
 */
export class MapExpression
  extends Expression
  implements Container<[Expression, Expression], NewNodeForMapExpression>
{
  readonly sassType = 'map' as const;
  declare raws: MapExpressionRaws;

  get nodes(): ReadonlyArray<[Expression, Expression]> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<[Expression, Expression]>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes?: Array<[Expression, Expression]>;

  /**
   * Iterators that are currently active within this map. Their indices refer
   * to the last position that has already been sent to the callback, and are
   * updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults: MapExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.MapExpression);
  constructor(defaults?: object, inner?: sassInternal.MapExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.nodes = [];
      for (const pair of inner.pairs) {
        this.append([convertExpression(pair.$1), convertExpression(pair.$2)]);
      }
    }
  }

  clone(overrides?: Partial<MapExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['nodes']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  append(...nodes: NewNodeForMapExpression[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: [Expression, Expression], index: number) => false | void,
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

  every(
    condition: (
      node: [Expression, Expression],
      index: number,
      nodes: ReadonlyArray<[Expression, Expression]>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: [Expression, Expression] | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: [Expression, Expression] | number,
    newNode: NewNodeForMapExpression,
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

  insertBefore(
    oldNode: [Expression, Expression] | number,
    newNode: NewNodeForMapExpression,
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

  prepend(...nodes: NewNodeForMapExpression[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: [Expression, Expression]): this {
    return this.append(child);
  }

  removeAll(): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    for (const node of this.nodes) {
      node[0].parent = undefined;
      node[1].parent = undefined;
    }
    this._nodes!.length = 0;
    return this;
  }

  removeChild(child: [Expression, Expression] | number): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(child);
    const node = this._nodes![index];
    if (node) {
      node[0].parent = undefined;
      node[1].parent = undefined;
    }
    this._nodes!.splice(index, 1);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index--;
    }

    return this;
  }

  some(
    condition: (
      node: [Expression, Expression],
      index: number,
      nodes: ReadonlyArray<[Expression, Expression]>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): [Expression, Expression] | undefined {
    return this.nodes[0];
  }

  get last(): [Expression, Expression] | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';

    result += '(' + (this.raws?.afterOpen ?? '');

    const rawPairs = this.raws.pairs;
    for (let i = 0; i < this.nodes.length; i++) {
      const [key, value] = this.nodes[i];
      const raw = rawPairs?.[i];
      result +=
        (raw?.before ?? (i > 0 ? ' ' : '')) + key + (raw?.between ?? ': ');
      value + (raw?.after ?? '') + (i < this.nodes.length - 1 ? ',' : '');
    }

    if (this.raws.trailingComma && this.nodes.length > 0) result += ',';
    result += (this.raws?.beforeClose ?? '') + ')';
    return result;
  }

  /**
   * Normalizes a single argument declaration or map of arguments.
   */
  private _normalize(
    nodes: NewNodeForMapExpression,
  ): Array<[Expression, Expression]> {
    if (nodes === undefined) return [];
    const normalized: Array<[Expression, Expression]> = [];
    for (const node of Array.isArray(nodes) && Array.isArray(nodes[0])
      ? // We have to convert through unknown here because TypeScript incorrectly
        // narrows `nodes` to `[Expression, Expression] | [ExpressionProps,
        // ExpressionProps]` here, despite the fact that the second
        // `Array.isArray()` check makes that impossible.
        (nodes as unknown as
          | ReadonlyArray<[Expression, Expression]>
          | ReadonlyArray<[ExpressionProps, ExpressionProps]>)
      : [
          nodes as
            | [Expression, Expression]
            | [ExpressionProps, ExpressionProps],
        ]) {
      if (node === undefined) {
        continue;
      } else if ('sassType' in node[0] && 'sassType' in node[1]) {
        node[0].parent = this;
        node[1].parent = this;
        normalized.push(node as [Expression, Expression]);
      } else {
        const constructedKey = fromProps(node[0] as ExpressionProps);
        constructedKey.parent = this;
        const constructedValue = fromProps(node[1] as ExpressionProps);
        constructedValue.parent = this;
        normalized.push([constructedKey, constructedValue]);
      }
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a map of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForMapExpression>,
  ): Array<[Expression, Expression]> {
    const result: Array<[Expression, Expression]> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return this.nodes.flat(1);
  }
}
