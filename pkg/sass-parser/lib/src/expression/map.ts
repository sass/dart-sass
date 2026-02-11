// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Container} from '../container';
import {LazySource} from '../lazy-source';
import {Node, NodeProps} from '../node';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';
import {convertExpression} from './convert';
import {MapEntry, MapEntryProps} from './map-entry';

/**
 * The initializer properties for {@link MapExpression}.
 *
 * @category Expression
 */
export interface MapExpressionProps extends NodeProps {
  raws?: MapExpressionRaws;
  nodes: Array<MapEntry | MapEntryProps>;
}

// TODO: Parse strings.
/**
 * The type of new node pairs that can be passed into a map expression.
 *
 * @category Expression
 */
export type NewNodeForMapExpression =
  | MapEntry
  | MapEntryProps
  | ReadonlyArray<MapEntry>
  | ReadonlyArray<MapEntryProps>
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
}

/**
 * An expression representing a map literal in Sass.
 *
 * @category Expression
 */
export class MapExpression
  extends Expression
  implements Container<MapEntry, NewNodeForMapExpression>
{
  readonly sassType = 'map' as const;
  declare raws: MapExpressionRaws;

  get nodes(): ReadonlyArray<MapEntry> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<MapEntry>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  declare private _nodes?: Array<MapEntry>;

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
        this.append([convertExpression(pair._0), convertExpression(pair._1)]);
      }
    }
  }

  clone(overrides?: Partial<MapExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['nodes', 'raws']);
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
    callback: (node: MapEntry, index: number) => false | void,
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
      node: MapEntry,
      index: number,
      nodes: ReadonlyArray<MapEntry>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: MapEntry | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: MapEntry | number,
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
    oldNode: MapEntry | number,
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

  push(child: MapEntry): this {
    return this.append(child);
  }

  removeAll(): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    for (const node of this.nodes) {
      node.parent = undefined;
    }
    this._nodes!.length = 0;
    return this;
  }

  removeChild(child: MapEntry | number): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(child);
    const node = this._nodes![index];
    if (node) node.parent = undefined;
    this._nodes!.splice(index, 1);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index--;
    }

    return this;
  }

  some(
    condition: (
      node: MapEntry,
      index: number,
      nodes: ReadonlyArray<MapEntry>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): MapEntry | undefined {
    return this.nodes[0];
  }

  get last(): MapEntry | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';

    result += '(' + (this.raws?.afterOpen ?? '');

    for (let i = 0; i < this.nodes.length; i++) {
      const entry = this.nodes[i];
      result +=
        (entry.raws.before ?? (i > 0 ? ' ' : '')) +
        entry +
        (entry.raws.after ?? '') +
        (i < this.nodes.length - 1 ? ',' : '');
    }

    if (this.raws.trailingComma && this.nodes.length > 0) result += ',';
    result += (this.raws?.beforeClose ?? '') + ')';
    return result;
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(nodes: NewNodeForMapExpression): Array<MapEntry> {
    if (nodes === undefined) return [];
    const normalized: Array<MapEntry> = [];
    // We need a lot of weird casts here because TypeScript gets confused by the
    // way these types overlap.
    const nodesArray: Array<MapEntry | MapEntryProps> = Array.isArray(nodes)
      ? // nodes is now
        // | [Expression | ExpressionProps, Expression | ExpressionProps]
        // | ReadonlyArray<MapEntry>
        // | ReadonlyArray<MapEntryProps>
        // ReadonlyArray<MapEntry>
        isMapEntry(nodes[0]) ||
        // ReadonlyArray<MapEntryProps> when the first entry is
        // [Expression | ExpressionProps, Expression | ExpressionProps].
        Array.isArray(nodes[0]) ||
        // ReadonlyArray<MapEntryProps> when the first entry is
        // MapEntryObjectProps.
        ('key' in nodes[0] && 'value' in nodes[0])
        ? (nodes as unknown as Array<MapEntry | MapEntryProps>)
        : // If it's not one of the above patterns, it must be a raw MapEntryProps
          // of the form [Expression | ExpressionProps, Expression |
          // ExpressionProps].
          [nodes]
      : [nodes as MapEntryProps];
    for (const node of nodesArray) {
      if (node === undefined) {
        continue;
      } else if ('sassType' in node) {
        if (!isMapEntry(node)) {
          throw new Error(
            `Unexpected "${(node as unknown as Node).sassType}", expected "map-entry".`,
          );
        }
        node.parent = this;
        normalized.push(node);
      } else {
        const entry = new MapEntry(node);
        entry.parent = this;
        normalized.push(entry);
      }
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForMapExpression>,
  ): Array<MapEntry> {
    const result: Array<MapEntry> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<MapEntry> {
    return this.nodes;
  }
}

function isMapEntry(value: object): value is MapEntry {
  return 'sassType' in value && value.sassType === 'map-entry';
}
