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
import {ComplexSelector, ComplexSelectorProps} from './complex';

/**
 * The initializer properties for {@link SelectorList} passed as an options
 * object.
 *
 * @category Selector
 */
export interface SelectorListObjectProps extends NodeProps {
  nodes: Array<ComplexSelector | ComplexSelectorProps>;
  raws?: SelectorListRaws;
}

/**
 * The initializer properties for {@link SelectorList}.
 *
 * @category Selector
 */
export type SelectorListProps =
  | SelectorListObjectProps
  | ReadonlyArray<ComplexSelector | ComplexSelectorProps>
  | ComplexSelector
  | ComplexSelectorProps;

// TODO: Parse strings.
/**
 * The type of new nodes that can be passed into a complex selector.
 *
 * @category Selector
 */
export type NewNodeForSelectorList =
  | ComplexSelector
  | ReadonlyArray<ComplexSelector>
  | ComplexSelectorProps
  | ReadonlyArray<ComplexSelectorProps>
  | undefined;

/**
 * Raws indicating how to precisely serialize an {@SelectorList}.
 *
 * @category Selector
 */
export interface SelectorListRaws {
  /**
   * The whitespace before and after each complex selector in the list.
   *
   * `before` is the whitespace between the previous comma and the complex
   * selector and `after` is the whitespace between the complex selector and the
   * next comma. `before` is never set by default for the first complex
   * selector, and `after` is never set by default for the last one.
   */
  complexes?: Array<{before?: string; after?: string} | undefined>;
}

/**
 * A selector list.
 *
 * A selector list is composed of {@link ComplexSelector}s. It matches any
 * element that matches any of the component selectors.
 *
 * @category Selector
 */
export class SelectorList
  extends Node
  implements Container<ComplexSelector, NewNodeForSelectorList>
{
  readonly sassType = 'selector-list' as const;
  declare raws: SelectorListRaws;

  /** The components that comprise this selector. */
  get nodes(): ReadonlyArray<ComplexSelector> {
    return this._nodes;
  }
  /** @hidden */
  set nodes(nodes: Array<ComplexSelector>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes: Array<ComplexSelector>;

  /**
   * Iterators that are currently active within this selector. Their indices
   * refer to the last position that has already been sent to the callback, and
   * are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: SelectorListProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.SelectorList);
  constructor(defaults?: object, inner?: sassInternal.SelectorList) {
    if (defaults) {
      if (
        !Array.isArray(defaults) &&
        'nodes' in defaults &&
        !('sassType' in defaults)
      ) {
        defaults.nodes = [defaults.nodes];
      } else {
        // Wrap an array in an extra array because PostCSS calls
        // append(...nodes). This ensures that the array is processed, as a
        // unit, by [_normalize]. This in turn means that an array of arrays is
        // processed as a single complex.
        defaults = {nodes: [defaults]};
      }
    }

    super(defaults);
    this.nodes ??= [];
    if (inner) {
      this.source = new LazySource(inner);
      this.nodes = [];
      for (const complex of inner.components) {
        this.append(new ComplexSelector(undefined, complex));
      }
    }
  }

  clone(overrides?: Partial<SelectorListObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'nodes']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  append(...nodes: NewNodeForSelectorList[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: ComplexSelector, index: number) => false | void,
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
      node: ComplexSelector,
      index: number,
      nodes: ReadonlyArray<ComplexSelector>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: ComplexSelector | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: ComplexSelector | number,
    newNode: NewNodeForSelectorList,
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
    oldNode: ComplexSelector | number,
    newNode: NewNodeForSelectorList,
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

  prepend(...nodes: NewNodeForSelectorList[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: ComplexSelector): this {
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

  removeChild(child: ComplexSelector | number): this {
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
      node: ComplexSelector,
      index: number,
      nodes: ReadonlyArray<ComplexSelector>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): ComplexSelector | undefined {
    return this.nodes[0];
  }

  get last(): ComplexSelector | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';

    const rawComplexes = this.raws.complexes;
    for (let i = 0; i < this.nodes.length; i++) {
      const element = this.nodes[i];
      const raw = rawComplexes?.[i];
      result += raw?.before ?? (i > 0 ? ' ' : '');
      result += element;
      result += raw?.after ?? '';
      result += i < this.nodes.length - 1 ? ',' : '';
    }

    return result;
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(nodes: NewNodeForSelectorList): ComplexSelector[] {
    if (nodes === undefined) return [];
    const normalized: ComplexSelector[] = [];
    for (const node of Array.isArray(nodes) ? nodes : [nodes]) {
      if (node === undefined) {
        continue;
      } else if ('sassType' in node && node.sassType === 'complex-selector') {
        node.parent = this;
        normalized.push(node);
      } else {
        const constructed = new ComplexSelector(node);
        constructed.parent = this;
        normalized.push(constructed);
      }
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForSelectorList>,
  ): ComplexSelector[] {
    const result: Array<ComplexSelector> = [];
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
