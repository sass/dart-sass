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
 * Possible separators for Sass lists. `' '` indicates a list that's separated
 * on expression boundaries, not necessarily a space character specifically.
 * `null` indicates a zero- or one-element list that doesn't explicitly specify
 * a separator.
 *
 * @category Expression
 */
export type ListSeparator = ' ' | ',' | '/' | null;

/**
 * The initializer properties for {@link ListExpression}.
 *
 * @category Expression
 */
export interface ListExpressionProps extends NodeProps {
  raws?: ListExpressionRaws;
  separator: ListSeparator;
  nodes: Array<Expression | ExpressionProps>;
  brackets?: boolean;
}

// TODO: Parse strings.
/**
 * The type of new nodes that can be passed into a list expression.
 *
 * @category Expression
 */
export type NewNodeForListExpression =
  | Expression
  | ReadonlyArray<Expression>
  | ExpressionProps
  | ReadonlyArray<ExpressionProps>
  | undefined;

/**
 * Raws indicating how to precisely serialize a {@link ListExpression}.
 *
 * @category Expression
 */
export interface ListExpressionRaws {
  /**
   * The whitespace between the opening bracket and the first expression.
   *
   * For zero-element lists, this is the whitespace between the brackets.
   *
   * This is ignored for unbracketed lists with more than zero elements.
   */
  afterOpen?: string;

  /**
   * The whitespace between the last comma and the closing bracket.
   *
   * This is only set automatically for lists with trailing commas.
   *
   * This is ignored for unbracketed lists with more than zero elements.
   */
  beforeClose?: string;

  /**
   * Whether this list has a trailing comma.
   *
   * Ignored if {@link ListExpression.separator} isn't `','`, or if the
   * expression has fewer than two elements.
   */
  trailingComma?: boolean;

  /**
   * The whitespace before and after each expression in the list.
   *
   * For space-separated lists, `before` is never automatically set. For comma-
   * or slash-separated lists, `before` is the whitespace between the previous
   * separator and the expression and `after` is the whitespace between the
   * expression and the next separator or the closing bracket.
   */
  expressions?: Array<{before?: string; after?: string} | undefined>;
}

/**
 * An expression representing a list literal in Sass.
 *
 * @category Expression
 */
export class ListExpression
  extends Expression
  implements Container<Expression, NewNodeForListExpression>
{
  readonly sassType = 'list' as const;
  declare raws: ListExpressionRaws;

  /** This list's separator. */
  get separator(): ListSeparator {
    return this._separator;
  }
  set separator(separator: ListSeparator) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._separator = separator;
  }
  private declare _separator: ListSeparator;

  /**
   * Whether the list has square brackets (as opposed to no brackets). This
   * defaults to false.
   */
  get brackets(): boolean {
    return this._brackets;
  }
  set brackets(brackets: boolean) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._brackets = brackets;
  }
  private declare _brackets: boolean;

  get nodes(): ReadonlyArray<Expression> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<Expression>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes?: Array<Expression>;

  /**
   * Iterators that are currently active within this list. Their indices refer
   * to the last position that has already been sent to the callback, and are
   * updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults: ListExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ListExpression);
  constructor(defaults?: object, inner?: sassInternal.ListExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.nodes = [];
      for (const expression of inner.contents) {
        this.append(convertExpression(expression));
      }
      this.separator = inner.separator.separator ?? null;
      this.brackets = inner.hasBrackets;
    }
    this.brackets ??= false;
  }

  clone(overrides?: Partial<ListExpressionProps>): this {
    return utils.cloneNode(this, overrides, [
      'separator',
      'brackets',
      'nodes',
      'raws',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['separator', 'brackets', 'nodes'], inputs);
  }

  append(...nodes: NewNodeForListExpression[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: Expression, index: number) => false | void,
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
      node: Expression,
      index: number,
      nodes: ReadonlyArray<Expression>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: Expression | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: Expression | number,
    newNode: NewNodeForListExpression,
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
    oldNode: Expression | number,
    newNode: NewNodeForListExpression,
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

  prepend(...nodes: NewNodeForListExpression[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: Expression): this {
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

  removeChild(child: Expression | number): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(child);
    const argument = this._nodes![index];
    if (argument) argument.parent = undefined;
    this._nodes!.splice(index, 1);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index--;
    }

    return this;
  }

  some(
    condition: (
      node: Expression,
      index: number,
      nodes: ReadonlyArray<Expression>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): Expression | undefined {
    return this.nodes[0];
  }

  get last(): Expression | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';

    if (this.brackets || this.nodes.length === 0) {
      if (this.brackets) {
        result += '[';
      } else {
        result += '(';
      }
      result += this.raws?.afterOpen ?? '';
    }

    const rawExpressions = this.raws.expressions;
    for (let i = 0; i < this.nodes.length; i++) {
      const element = this.nodes[i];
      const raw = rawExpressions?.[i];
      result +=
        raw?.before ??
        (i > 0 && (this.separator === ',' || this.separator === '/')
          ? ' '
          : '');
      result += element;
      result +=
        raw?.after ??
        (i < this.nodes.length - 1 && this.separator !== ',' ? ' ' : '');
      result +=
        i < this.nodes.length - 1 &&
        this.separator !== ' ' &&
        this.separator !== null
          ? this.separator
          : '';
    }

    if (
      this.separator === ',' &&
      (this.nodes.length < 2 || this.raws.trailingComma)
    ) {
      result += ',';
    }
    if (this.brackets || this.nodes.length === 0) {
      result += this.raws?.beforeClose ?? '';
      if (this.brackets) {
        result += ']';
      } else {
        result += ')';
      }
    }

    return result;
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(nodes: NewNodeForListExpression): Expression[] {
    if (nodes === undefined) return [];
    const normalized: Expression[] = [];
    for (const node of Array.isArray(nodes) ? nodes : [nodes]) {
      if (node === undefined) {
        continue;
      } else if ('sassType' in node) {
        node.parent = this;
        normalized.push(node);
      } else {
        const constructed = fromProps(node);
        constructed.parent = this;
        normalized.push(constructed);
      }
      node.parent = this;
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForListExpression>,
  ): Expression[] {
    const result: Array<Expression> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return this.nodes;
  }
}
