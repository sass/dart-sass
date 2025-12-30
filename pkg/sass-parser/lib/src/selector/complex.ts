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
import {
  ComplexSelectorComponent,
  ComplexSelectorComponentProps,
} from './complex-component';

/**
 * A selector combinator that can separate {@link CompoundSelector}s in a {@link
 * ComplexSelector}.
 */
export type SelectorCombinator = '+' | '>' | '~';

/**
 * The initializer properties for {@link ComplexSelector} passed as an options
 * object.
 *
 * @category Selector
 */
export interface ComplexSelectorObjectProps extends NodeProps {
  leadingCombinator?: SelectorCombinator | undefined;
  nodes: Array<ComplexSelectorComponent | ComplexSelectorComponentProps>;
  raws?: ComplexSelectorRaws;
}

/**
 * The initializer properties for {@link ComplexSelector}.
 *
 * @category Selector
 */
export type ComplexSelectorProps =
  | ComplexSelectorObjectProps
  | ReadonlyArray<ComplexSelectorComponent | ComplexSelectorComponentProps>
  | ComplexSelectorComponent
  | ComplexSelectorComponentProps;

// TODO: Parse strings.
/**
 * The type of new nodes that can be passed into a complex selector.
 *
 * @category Selector
 */
export type NewNodeForComplexSelector =
  | ComplexSelectorComponent
  | ReadonlyArray<ComplexSelectorComponent>
  | ComplexSelectorComponentProps
  | ReadonlyArray<ComplexSelectorComponentProps>
  | undefined;

/**
 * Raws indicating how to precisely serialize an {@ComplexSelector}.
 *
 * @category Selector
 */
export interface ComplexSelectorRaws {
  /**
   * The whitespace between the leading combinator and the first component.
   *
   * This is ignored if {@link ComplexSelector.leadingCombinator} is undefined.
   */
  between?: string;

  /** The whitespace after each component in the selector. */
  components?: Array<string | undefined>;
}

/**
 * A complex selector.
 *
 * A complex selector is composed of {@link ComplexSelectorComponent}s. It
 * selects elements based on selectors for other, related elements.
 *
 * @category Selector
 */
export class ComplexSelector
  extends Node
  implements Container<ComplexSelectorComponent, NewNodeForComplexSelector>
{
  readonly sassType = 'complex-selector' as const;
  declare raws: ComplexSelectorRaws;

  /** This selector's leading combinator, if it has one. */
  get leadingCombinator(): SelectorCombinator | undefined {
    return this._leadingCombinator;
  }
  set leadingCombinator(value: SelectorCombinator | undefined) {
    this._leadingCombinator = value;
  }
  private declare _leadingCombinator: SelectorCombinator | undefined;

  /** The components that comprise this selector. */
  get nodes(): ReadonlyArray<ComplexSelectorComponent> {
    return this._nodes;
  }
  /** @hidden */
  set nodes(nodes: Array<ComplexSelectorComponent>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes: Array<ComplexSelectorComponent>;

  /**
   * Iterators that are currently active within this selector. Their indices
   * refer to the last position that has already been sent to the callback, and
   * are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: ComplexSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ComplexSelector);
  constructor(defaults?: object, inner?: sassInternal.ComplexSelector) {
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
        // processed as a single compound.
        defaults = {nodes: [defaults]};
      }
    }

    super(defaults);
    this.nodes ??= [];
    if (inner) {
      this.source = new LazySource(inner);
      // Multiple combinators will be removed soon so we don't bother
      // supporting it here.
      this.leadingCombinator =
        inner.leadingCombinator?.toString() as SelectorCombinator;
      for (const component of inner.components) {
        this.append(new ComplexSelectorComponent(undefined, component));
      }
    }
  }

  clone(overrides?: Partial<ComplexSelectorObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'leadingCombinator', explicitUndefined: true},
      'nodes',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['leadingCombinator', 'nodes'], inputs);
  }

  append(...nodes: NewNodeForComplexSelector[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: ComplexSelectorComponent, index: number) => false | void,
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
      node: ComplexSelectorComponent,
      index: number,
      nodes: ReadonlyArray<ComplexSelectorComponent>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: ComplexSelectorComponent | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: ComplexSelectorComponent | number,
    newNode: NewNodeForComplexSelector,
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
    oldNode: ComplexSelectorComponent | number,
    newNode: NewNodeForComplexSelector,
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

  prepend(...nodes: NewNodeForComplexSelector[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: ComplexSelectorComponent): this {
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

  removeChild(child: ComplexSelectorComponent | number): this {
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
      node: ComplexSelectorComponent,
      index: number,
      nodes: ReadonlyArray<ComplexSelectorComponent>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): ComplexSelectorComponent | undefined {
    return this.nodes[0];
  }

  get last(): ComplexSelectorComponent | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';
    if (this.leadingCombinator) {
      result += this.leadingCombinator + (this.raws.between ?? ' ');
    }

    const rawComponents = this.raws.components;
    for (let i = 0; i < this.nodes.length; i++) {
      const component = this.nodes[i];
      const raw = rawComponents?.[i];
      result += component + (raw ?? (i < this.nodes.length - 1 ? ' ' : ''));
    }
    return result;
  }

  /**
   * Normalizes a single argument declaration or list of arguments.
   */
  private _normalize(
    nodes: NewNodeForComplexSelector,
  ): ComplexSelectorComponent[] {
    if (nodes === undefined) return [];
    const normalized: ComplexSelectorComponent[] = [];
    for (const node of Array.isArray(nodes) ? nodes : [nodes]) {
      if (node === undefined) {
        continue;
      } else if (
        'sassType' in node &&
        node.sassType === 'complex-selector-component'
      ) {
        node.parent = this;
        normalized.push(node);
      } else {
        const constructed = new ComplexSelectorComponent(node);
        constructed.parent = this;
        normalized.push(constructed);
      }
    }
    return normalized;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForComplexSelector>,
  ): ComplexSelectorComponent[] {
    const result: Array<ComplexSelectorComponent> = [];
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
