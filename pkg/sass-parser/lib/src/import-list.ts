// Copyright 2024 Google Inc. Import of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Container} from './container';
import {DynamicImport, DynamicImportProps} from './dynamic-import';
import {LazySource} from './lazy-source';
import {Node, NodeProps} from './node';
import {ImportRule} from './statement/import-rule';
import {StaticImport, StaticImportProps} from './static-import';
import * as sassInternal from './sass-internal';
import * as utils from './utils';

/**
 * The type of new imports that can be passed into an {@link ImportList}.
 *
 * @category Statement
 */
export type NewImport =
  | StaticImport
  | DynamicImport
  | StaticImportProps
  | DynamicImportProps
  | ReadonlyArray<
      | StaticImport
      | DynamicImport
      | StaticImportProps
      | DynamicImportProps
      | undefined
    >
  | undefined;

/**
 * The set of raws supported by {@link ImportList}.
 *
 * @category Statement
 */
export type ImportListRaws = {};

/**
 * The initializer properties for {@link ImportList} passed as an options
 * object.
 *
 * @category Statement
 */
export interface ImportListObjectProps extends NodeProps {
  raws?: ImportListRaws;
  nodes: Array<DynamicImportProps | StaticImportProps>;
}

/**
 * The initializer properties for {@link ImportList}.
 *
 * @category Statement
 */
export type ImportListProps =
  | string
  | Array<DynamicImportProps | StaticImportProps>
  | ImportListObjectProps;

/**
 * A `@import` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ImportList
  extends Node
  implements Container<DynamicImport | StaticImport, NewImport>
{
  readonly sassType = 'import-list' as const;
  declare parent: ImportRule | undefined;
  declare raws: ImportListRaws;

  /** The imports loaded by this rule. */
  get nodes(): ReadonlyArray<DynamicImport | StaticImport> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<DynamicImport | StaticImport>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  private declare _nodes?: Array<DynamicImport | StaticImport>;

  get name(): string {
    return 'import';
  }
  set name(value: string) {
    throw new Error("ImportList.name can't be overwritten.");
  }

  /**
   * Iterators that are currently active within this rule's {@link nodes}.
   * Their indices refer to the last position that has already been sent to the
   * callback, and are updated when {@link _imports} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults?: ImportListProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ImportRule);
  constructor(defaults?: ImportListProps, inner?: sassInternal.ImportRule) {
    if (typeof defaults === 'string') {
      super({nodes: [defaults]});
    } else if (Array.isArray(defaults)) {
      super({nodes: defaults});
    } else {
      super(defaults);
    }
    this.raws ??= {};
    this._nodes ??= [];

    if (inner) {
      this.source = new LazySource(inner);
      for (const imp of inner.imports) {
        this.append(
          'urlString' in imp
            ? new DynamicImport(undefined, imp)
            : new StaticImport(undefined, imp),
        );
      }
    }
  }

  clone(overrides?: Partial<ImportListObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'nodes']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  append(...nodes: NewImport[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (
      node: DynamicImport | StaticImport,
      index: number,
    ) => false | void,
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
      node: DynamicImport | StaticImport,
      index: number,
      nodes: ReadonlyArray<DynamicImport | StaticImport>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: DynamicImport | StaticImport | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: DynamicImport | StaticImport | number,
    newNode: NewImport,
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
    oldNode: DynamicImport | StaticImport | number,
    newNode: NewImport,
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

  prepend(...nodes: NewImport[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: DynamicImport | StaticImport): this {
    return this.append(child);
  }

  removeAll(): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    for (const node of this.nodes) {
      if (typeof node !== 'string') node.parent = undefined;
    }
    this._nodes!.length = 0;
    return this;
  }

  removeChild(child: DynamicImport | StaticImport | number): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const index = this.index(child);
    child = this._nodes![index];
    if (typeof child === 'object') child.parent = undefined;
    this._nodes!.splice(index, 1);

    for (const iterator of this.#iterators) {
      if (iterator.index >= index) iterator.index--;
    }

    return this;
  }

  some(
    condition: (
      node: DynamicImport | StaticImport,
      index: number,
      nodes: ReadonlyArray<DynamicImport | StaticImport>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): DynamicImport | StaticImport | undefined {
    return this.nodes[0];
  }

  get last(): DynamicImport | StaticImport | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /**
   * Normalizes the many types of node that can be used with Interpolation
   * methods.
   */
  private _normalize(nodes: NewImport): Array<DynamicImport | StaticImport> {
    const result: Array<DynamicImport | StaticImport> = [];
    for (const node of Array.isArray(nodes) ? nodes : [nodes]) {
      if (node === undefined) {
        continue;
      } else if (typeof node === 'object' && 'sassType' in node) {
        node.parent = this;
        result.push(node);
      } else {
        const constructed =
          typeof node === 'string' || 'url' in node
            ? new DynamicImport(node)
            : new StaticImport(node);
        constructed.parent = this;
        result.push(constructed);
      }
    }
    return result;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewImport>,
  ): Array<DynamicImport | StaticImport> {
    const result: Array<DynamicImport | StaticImport> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  toString(): string {
    return this.nodes
      .map(
        (imp, i) =>
          (imp.raws?.before ?? (i === 0 ? '' : ' ')) +
          imp +
          (imp.raws?.after ?? ''),
      )
      .join(',');
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<DynamicImport | StaticImport> {
    return this.nodes;
  }
}
