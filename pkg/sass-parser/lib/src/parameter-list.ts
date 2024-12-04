// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Container} from './container';
import {Parameter, ParameterProps} from './parameter';
import {LazySource} from './lazy-source';
import {Node} from './node';
import {RawWithValue} from './raw-with-value';
import * as sassInternal from './sass-internal';
import * as utils from './utils';

/**
 * The type of new nodes that can be passed into a parameter list, either a
 * single parameter or multiple parameters.
 *
 * @category Statement
 */
export type NewParameters =
  | Parameter
  | ParameterProps
  | ReadonlyArray<Parameter | ParameterProps>
  | undefined;

/**
 * The initializer properties for {@link ParameterList} passed as an options
 * object.
 *
 * @category Statement
 */
export interface ParameterListObjectProps {
  nodes?: ReadonlyArray<ParameterProps>;
  restParameter?: string;
  raws?: ParameterListRaws;
}

/**
 * The initializer properties for {@link ParameterList}.
 *
 * @category Statement
 */
export type ParameterListProps =
  | ParameterListObjectProps
  | ReadonlyArray<ParameterProps>;

/**
 * Raws indicating how to precisely serialize a {@link ParameterList} node.
 *
 * @category Statement
 */
export interface ParameterListRaws {
  /** Whitespace before the rest parameter, if one exists. */
  beforeRestParameter?: string;

  /**
   * The name of the rest parameter, if one exists.
   *
   * This may be different than {@link ParameterList.restParameter} if the name
   * contains escape codes or underscores.
   */
  restParameter?: RawWithValue<string>;

  /**
   * Whether the final parameter has a trailing comma.
   *
   * Ignored if {@link ParameterList.nodes} is empty or if
   * {@link ParameterList.restParameter} is set.
   */
  comma?: boolean;

  /**
   * The whitespace between the final parameter (or its trailing comma if it has
   * one) and the closing parenthesis.
   */
  after?: string;
}

/**
 * A list of parameters, as in a `@function` or `@mixin` rule.
 *
 * @category Statement
 */
export class ParameterList
  extends Node
  implements Container<Parameter, NewParameters>
{
  readonly sassType = 'parameter-list' as const;
  declare raws: ParameterListRaws;

  get nodes(): ReadonlyArray<Parameter> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<Parameter>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private _nodes?: Array<Parameter>;

  /**
   * The name of the rest parameter (such as `args` in `...$args`) in this
   * parameter list.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare restParameter?: string;

  /**
   * Iterators that are currently active within this parameter list. Their
   * indices refer to the last position that has already been sent to the
   * callback, and are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: ParameterListProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ArgumentDeclaration);
  constructor(defaults?: object, inner?: sassInternal.ArgumentDeclaration) {
    super(Array.isArray(defaults) ? {nodes: defaults} : defaults);
    if (inner) {
      this.source = new LazySource(inner);
      // TODO: set lazy raws here to use when stringifying
      this._nodes = [];
      this.restParameter = inner.restArgument ?? undefined;
      for (const argument of inner.arguments) {
        this.append(new Parameter(undefined, argument));
      }
    }
    if (this._nodes === undefined) this._nodes = [];
  }

  clone(overrides?: Partial<ParameterListObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'nodes',
      {name: 'restParameter', explicitUndefined: true},
      'raws',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes', 'restParameter'], inputs);
  }

  append(...nodes: NewParameters[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: Parameter, index: number) => false | void,
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
      node: Parameter,
      index: number,
      nodes: ReadonlyArray<Parameter>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: Parameter | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(oldNode: Parameter | number, newNode: NewParameters): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(oldNode);
    const normalized = this._normalize(newNode);
    this._nodes!.splice(index + 1, 0, ...normalized);

    for (const iterator of this.#iterators) {
      if (iterator.index > index) iterator.index += normalized.length;
    }

    return this;
  }

  insertBefore(oldNode: Parameter | number, newNode: NewParameters): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(oldNode);
    const normalized = this._normalize(newNode);
    this._nodes!.splice(index, 0, ...normalized);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index += normalized.length;
    }

    return this;
  }

  prepend(...nodes: NewParameters[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: Parameter): this {
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

  removeChild(child: Parameter | number): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(child);
    const parameter = this._nodes![index];
    if (parameter) parameter.parent = undefined;
    this._nodes!.splice(index, 1);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index--;
    }

    return this;
  }

  some(
    condition: (
      node: Parameter,
      index: number,
      nodes: ReadonlyArray<Parameter>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): Parameter | undefined {
    return this.nodes[0];
  }

  get last(): Parameter | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '(';
    let first = true;
    for (const parameter of this.nodes) {
      if (first) {
        result += parameter.raws.before ?? '';
        first = false;
      } else {
        result += ',';
        result += parameter.raws.before ?? ' ';
      }
      result += parameter.toString();
      result += parameter.raws.after ?? '';
    }

    if (this.restParameter) {
      if (this.nodes.length) {
        result += ',' + (this.raws.beforeRestParameter ?? ' ');
      } else if (this.raws.beforeRestParameter) {
        result += this.raws.beforeRestParameter;
      }
      result +=
        '$' +
        (this.raws.restParameter?.value === this.restParameter
          ? this.raws.restParameter.raw
          : sassInternal.toCssIdentifier(this.restParameter)) +
        '...';
    }
    if (this.raws.comma && this.nodes.length && !this.restParameter) {
      result += ',';
    }
    return result + (this.raws.after ?? '') + ')';
  }

  /**
   * Normalizes a single parameter declaration or list of parameters.
   */
  private _normalize(nodes: NewParameters): Parameter[] {
    const normalized = this._normalizeBeforeParent(nodes);
    for (const node of normalized) {
      node.parent = this;
    }
    return normalized;
  }

  /** Like {@link _normalize}, but doesn't set the parameter's parents. */
  private _normalizeBeforeParent(nodes: NewParameters): Parameter[] {
    if (nodes === undefined) return [];
    if (Array.isArray(nodes)) {
      if (
        nodes.length === 2 &&
        typeof nodes[0] === 'string' &&
        typeof nodes[1] === 'object' &&
        !('name' in nodes[1])
      ) {
        return [new Parameter(nodes)];
      } else {
        return (nodes as ReadonlyArray<Parameter | ParameterProps>).map(node =>
          typeof node === 'object' && 'sassType' in node
            ? (node as Parameter)
            : new Parameter(node),
        );
      }
    } else {
      return [
        typeof nodes === 'object' && 'sassType' in nodes
          ? (nodes as Parameter)
          : new Parameter(nodes as ParameterProps),
      ];
    }
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(nodes: ReadonlyArray<NewParameters>): Parameter[] {
    const result: Array<Parameter> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Parameter> {
    return this.nodes;
  }
}
