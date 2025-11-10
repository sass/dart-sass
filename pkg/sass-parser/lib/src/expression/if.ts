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
import {convertIfConditionExpression} from './if-condition-expression/convert';
import {IfEntry, IfEntryProps} from './if-entry';

/**
 * The initializer properties for {@link IfExpression}.
 *
 * @category Expression
 */
export interface IfExpressionProps extends NodeProps {
  raws?: IfExpressionRaws;
  nodes: Array<IfEntry | IfEntryProps>;
}

// TODO: Parse strings.
/**
 * The type of new node pairs that can be passed into an `if()` expression.
 *
 * @category Expression
 */
export type NewNodeForIfExpression =
  | IfEntry
  | IfEntryProps
  | ReadonlyArray<IfEntry>
  | ReadonlyArray<IfEntryProps>
  | undefined;

/**
 * Raws indicating how to precisely serialize a {@link IfExpression}.
 *
 * @category Expression
 */
export interface IfExpressionRaws {
  /**
   * The whitespace between the opening parenthesis and the first expression.
   */
  afterOpen?: string;

  /**
   * The whitespace between the last semicolon and the closing bracket.
   *
   * This is only set automatically for expressions with trailing semicolons.
   */
  beforeClose?: string;

  /**
   * Whether this expression has a trailing semicolon.
   *
   * Ignored if the expression has zero elements.
   */
  trailingSemi?: boolean;
}

/**
 * An expression representing an `if()` function in Sass.
 *
 * **Note:** Unlike other expression types, this can't be constructed from a
 * property object alone, because [IfExpressionProps] may be ambiguous with
 * [MapExpressionProps]. Instead, call `new IfExpression()` explicitly: For
 * example:
 *
 * ```ts
 * string.text.append(new IfExpression([
 *   [{variableName: 'important'}, {text: ' !important'}],
 *   ['else', {text: ''}],
 * ]));
 * ```
 *
 * @category Expression
 */
export class IfExpression
  extends Expression
  implements Container<IfEntry, NewNodeForIfExpression>
{
  readonly sassType = 'if-expr' as const;
  declare raws: IfExpressionRaws;

  get nodes(): ReadonlyArray<IfEntry> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<IfEntry>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes?: Array<IfEntry>;

  /**
   * Iterators that are currently active within this expression. Their indices
   * refer to the last position that has already been sent to the callback, and
   * are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults: IfExpressionProps | Array<IfEntry | IfEntryProps>);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfExpression);
  constructor(defaults?: object, inner?: sassInternal.IfExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.nodes = [];
      for (const branch of inner.branches) {
        this.append([
          branch._0 ? convertIfConditionExpression(branch._0) : 'else',
          convertExpression(branch._1),
        ]);
      }
    }
  }

  clone(overrides?: Partial<IfExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['nodes', 'raws']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  append(...nodes: NewNodeForIfExpression[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: IfEntry, index: number) => false | void,
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
      node: IfEntry,
      index: number,
      nodes: ReadonlyArray<IfEntry>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: IfEntry | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: IfEntry | number,
    newNode: NewNodeForIfExpression,
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
    oldNode: IfEntry | number,
    newNode: NewNodeForIfExpression,
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

  prepend(...nodes: NewNodeForIfExpression[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: IfEntry): this {
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

  removeChild(child: IfEntry | number): this {
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
      node: IfEntry,
      index: number,
      nodes: ReadonlyArray<IfEntry>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): IfEntry | undefined {
    return this.nodes[0];
  }

  get last(): IfEntry | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = 'if(' + (this.raws?.afterOpen ?? '');

    for (let i = 0; i < this.nodes.length; i++) {
      const entry = this.nodes[i];
      result +=
        (entry.raws.before ?? (i > 0 ? ' ' : '')) +
        entry +
        (entry.raws.after ?? '') +
        (i < this.nodes.length - 1 ? ';' : '');
    }

    if (this.raws.trailingSemi && this.nodes.length > 0) result += ';';
    result += (this.raws?.beforeClose ?? '') + ')';
    return result;
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(nodes: NewNodeForIfExpression): Array<IfEntry> {
    if (nodes === undefined) return [];
    const normalized: Array<IfEntry> = [];
    // We need a lot of weird casts here because TypeScript gets confused by the
    // way these types overlap.
    const nodesArray: Array<IfEntry | IfEntryProps> = Array.isArray(nodes)
      ? // nodes is now
        // | [Expression | ExpressionProps, Expression | ExpressionProps]
        // | ReadonlyArray<IfEntry>
        // | ReadonlyArray<IfEntryProps>
        // ReadonlyArray<IfEntry>
        isIfEntry(nodes[0]) ||
        // ReadonlyArray<IfEntryProps> when the first entry is
        // [Expression | ExpressionProps, Expression | ExpressionProps].
        Array.isArray(nodes[0]) ||
        // ReadonlyArray<IfEntryProps> when the first entry is
        // IfEntryObjectProps.
        (typeof nodes[0] === 'object' &&
          'condition' in nodes[0] &&
          'value' in nodes[0])
        ? (nodes as unknown as Array<IfEntry | IfEntryProps>)
        : // If it's not one of the above patterns, it must be a raw IfEntryProps
          // of the form [Expression | ExpressionProps, Expression |
          // ExpressionProps].
          [nodes]
      : [nodes as IfEntryProps];
    for (const node of nodesArray) {
      if (node === undefined) {
        continue;
      } else if ('sassType' in node) {
        if (!isIfEntry(node)) {
          throw new Error(
            `Unexpected "${(node as unknown as Node).sassType}", expected "if-entry".`,
          );
        }
        node.parent = this;
        normalized.push(node);
      } else {
        const entry = new IfEntry(node);
        entry.parent = this;
        normalized.push(entry);
      }
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForIfExpression>,
  ): Array<IfEntry> {
    const result: Array<IfEntry> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<IfEntry> {
    return this.nodes;
  }
}

function isIfEntry(value: unknown): value is IfEntry {
  return (
    !!value &&
    typeof value === 'object' &&
    'sassType' in value &&
    value.sassType === 'if-entry'
  );
}
