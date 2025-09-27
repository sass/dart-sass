// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Container} from '../container';
import {LazySource} from '../lazy-source';
import {AnyNode, Node, NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import {AnyStatement} from '../statement';
import * as utils from '../utils';
import {AnySimpleSelector, SimpleSelectorProps} from '.';
import {fromProps} from './from-props';
import {convertSimpleSelector} from './convert';

/**
 * The initializer properties for {@link CompoundSelector} passed as an options
 * object.
 *
 * @category Selector
 */
export interface CompoundSelectorObjectProps extends NodeProps {
  nodes: Array<AnySimpleSelector | SimpleSelectorProps>;
  raws?: CompoundSelectorRaws;
}

/**
 * The initializer properties for {@link CompoundSelector}.
 *
 * @category Selector
 */
export type CompoundSelectorProps =
  | CompoundSelectorObjectProps
  | ReadonlyArray<AnySimpleSelector | SimpleSelectorProps>
  | AnySimpleSelector
  | SimpleSelectorProps;

// TODO: Parse strings.
/**
 * The type of new nodes that can be passed into a compound selector.
 *
 * @category Selector
 */
export type NewNodeForCompoundSelector =
  | AnySimpleSelector
  | ReadonlyArray<AnySimpleSelector>
  | SimpleSelectorProps
  | ReadonlyArray<SimpleSelectorProps>
  | undefined;

/**
 * Raws indicating how to precisely serialize an {@CompoundSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a compound selector yet.
export interface CompoundSelectorRaws {}

/**
 * A compound selector.
 *
 * A compound selector is composed of {@link SimpleSelector}s. It matches an element
 * that matches all of the component simple selectors.
 *
 * @category Selector
 */
export class CompoundSelector
  extends Node
  implements Container<AnySimpleSelector, NewNodeForCompoundSelector>
{
  readonly sassType = 'compound-selector' as const;
  declare raws: CompoundSelectorRaws;

  /** The simple selectors that comprise this selector. */
  get nodes(): ReadonlyArray<AnySimpleSelector> {
    return this._nodes;
  }
  /** @hidden */
  set nodes(nodes: Array<AnySimpleSelector>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes: Array<AnySimpleSelector>;

  /**
   * Iterators that are currently active within this selector. Their indices
   * refer to the last position that has already been sent to the callback, and
   * are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: CompoundSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.CompoundSelector);
  constructor(defaults?: object, inner?: sassInternal.CompoundSelector) {
    if (Array.isArray(defaults)) {
      defaults = {nodes: defaults};
    } else if (defaults && !('nodes' in defaults)) {
      defaults = {nodes: [defaults]};
    }

    super(defaults);
    this.nodes ??= [];
    if (inner) {
      this.source = new LazySource(inner);
      for (const simple of inner.components) {
        this.append(convertSimpleSelector(simple));
      }
    }
  }

  clone(overrides?: Partial<CompoundSelectorObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'nodes']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  append(...nodes: NewNodeForCompoundSelector[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: AnySimpleSelector, index: number) => false | void,
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
      node: AnySimpleSelector,
      index: number,
      nodes: ReadonlyArray<AnySimpleSelector>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: AnySimpleSelector | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: AnySimpleSelector | number,
    newNode: NewNodeForCompoundSelector,
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
    oldNode: AnySimpleSelector | number,
    newNode: NewNodeForCompoundSelector,
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

  prepend(...nodes: NewNodeForCompoundSelector[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: AnySimpleSelector): this {
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

  removeChild(child: AnySimpleSelector | number): this {
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
      node: AnySimpleSelector,
      index: number,
      nodes: ReadonlyArray<AnySimpleSelector>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): AnySimpleSelector | undefined {
    return this.nodes[0];
  }

  get last(): AnySimpleSelector | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    return this.nodes.join('');
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(nodes: NewNodeForCompoundSelector): AnySimpleSelector[] {
    if (nodes === undefined) return [];
    const normalized: AnySimpleSelector[] = [];
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
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForCompoundSelector>,
  ): AnySimpleSelector[] {
    const result: Array<AnySimpleSelector> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return this.nodes;
  }
}
