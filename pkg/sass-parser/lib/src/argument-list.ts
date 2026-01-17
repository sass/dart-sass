// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Argument, ArgumentProps} from './argument';
import {Container} from './container';
import {convertExpression} from './expression/convert';
import {LazySource} from './lazy-source';
import {Node, NodeProps} from './node';
import * as sassInternal from './sass-internal';
import * as utils from './utils';

/**
 * The type of new nodes that can be passed into a argument list, either a
 * single argument or multiple arguments.
 *
 * @category Expression
 */
export type NewArguments =
  | Argument
  | ArgumentProps
  | ReadonlyArray<Argument | ArgumentProps>
  | undefined;

/**
 * The initializer properties for {@link ArgumentList} passed as an options
 * object.
 *
 * @category Expression
 */
export interface ArgumentListObjectProps extends NodeProps {
  nodes?: ReadonlyArray<NewArguments>;
  raws?: ArgumentListRaws;
}

/**
 * The initializer properties for {@link ArgumentList}.
 *
 * @category Expression
 */
export type ArgumentListProps =
  | ArgumentListObjectProps
  | ReadonlyArray<NewArguments>;

/**
 * Raws indicating how to precisely serialize a {@link ArgumentList} node.
 *
 * @category Expression
 */
export interface ArgumentListRaws {
  /**
   * Whether the final argument has a trailing comma.
   *
   * Ignored if {@link ArgumentList.nodes} is empty.
   */
  comma?: boolean;

  /**
   * The whitespace between the final argument (or its trailing comma if it has
   * one) and the closing parenthesis.
   */
  after?: string;
}

/**
 * A list of arguments, as in an `@include` rule or a function call.
 *
 * @category Expression
 */
export class ArgumentList
  extends Node
  implements Container<Argument, NewArguments>
{
  readonly sassType = 'argument-list' as const;
  declare raws: ArgumentListRaws;

  get nodes(): ReadonlyArray<Argument> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<Argument>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  declare private _nodes?: Array<Argument>;

  /**
   * Iterators that are currently active within this argument list. Their
   * indices refer to the last position that has already been sent to the
   * callback, and are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: ArgumentListProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ArgumentList);
  constructor(defaults?: object, inner?: sassInternal.ArgumentList) {
    super(Array.isArray(defaults) ? {nodes: defaults} : defaults);
    if (inner) {
      this.source = new LazySource(inner);
      // TODO: set lazy raws here to use when stringifying
      this._nodes = [];
      for (const expression of inner.positional) {
        this.append(new Argument(convertExpression(expression)));
      }
      for (const [name, expression] of Object.entries(
        sassInternal.mapToRecord(inner.named),
      )) {
        this.append(new Argument({name, value: convertExpression(expression)}));
      }
      if (inner.rest) {
        // TODO: Provide source information for this argument.
        this.append({value: convertExpression(inner.rest), rest: true});
      }
      if (inner.keywordRest) {
        // TODO: Provide source information for this argument.
        this.append({value: convertExpression(inner.keywordRest), rest: true});
      }
    }
    this._nodes ??= [];
  }

  clone(overrides?: Partial<ArgumentListObjectProps>): this {
    return utils.cloneNode(this, overrides, ['nodes', 'raws']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  append(...nodes: NewArguments[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: Argument, index: number) => false | void,
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
      node: Argument,
      index: number,
      nodes: ReadonlyArray<Argument>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: Argument | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(oldNode: Argument | number, newNode: NewArguments): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(oldNode);
    const normalized = this._normalize(newNode);
    this._nodes!.splice(index + 1, 0, ...normalized);

    for (const iterator of this.#iterators) {
      if (iterator.index > index) iterator.index += normalized.length;
    }

    return this;
  }

  insertBefore(oldNode: Argument | number, newNode: NewArguments): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(oldNode);
    const normalized = this._normalize(newNode);
    this._nodes!.splice(index, 0, ...normalized);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index += normalized.length;
    }

    return this;
  }

  prepend(...nodes: NewArguments[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: Argument): this {
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

  removeChild(child: Argument | number): this {
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
      node: Argument,
      index: number,
      nodes: ReadonlyArray<Argument>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): Argument | undefined {
    return this.nodes[0];
  }

  get last(): Argument | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '(';
    let first = true;
    for (const argument of this.nodes) {
      if (first) {
        result += argument.raws.before ?? '';
        first = false;
      } else {
        result += ',';
        result += argument.raws.before ?? ' ';
      }
      result += argument.toString();
      result += argument.raws.after ?? '';
    }
    if (this.raws.comma && this.nodes.length) result += ',';
    return result + (this.raws.after ?? '') + ')';
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(nodes: NewArguments): Argument[] {
    const normalized = this._normalizeBeforeParent(nodes);
    for (const node of normalized) {
      node.parent = this;
    }
    return normalized;
  }

  /** Like {@link _normalize}, but doesn't set the argument's parents. */
  private _normalizeBeforeParent(nodes: NewArguments): Argument[] {
    if (nodes === undefined) return [];
    if (Array.isArray(nodes)) {
      if (
        nodes.length === 2 &&
        typeof nodes[0] === 'string' &&
        typeof nodes[1] === 'object' &&
        !('name' in nodes[1])
      ) {
        return [new Argument(nodes)];
      } else {
        return (nodes as ReadonlyArray<Argument | ArgumentProps>).map(node =>
          typeof node === 'object' &&
          'sassType' in node &&
          node.sassType === 'argument'
            ? (node as Argument)
            : new Argument(node),
        );
      }
    } else {
      return [
        typeof nodes === 'object' &&
        'sassType' in nodes &&
        nodes.sassType === 'argument'
          ? (nodes as Argument)
          : new Argument(nodes as ArgumentProps),
      ];
    }
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(nodes: ReadonlyArray<NewArguments>): Argument[] {
    const result: Array<Argument> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Argument> {
    return this.nodes;
  }
}
