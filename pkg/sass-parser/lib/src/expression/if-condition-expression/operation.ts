// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {NodeProps} from '../../node';
import type * as sassInternal from '../../sass-internal';
import * as utils from '../../utils';
import {fromProps} from './from-props';
import {
  AnyIfConditionExpression,
  IfConditionExpression,
  IfConditionExpressionProps,
} from './index';
import {IfEntry} from '../if-entry';
import {LazySource} from '../../lazy-source';
import {convertIfConditionExpression} from './convert';
import {RawWithValue} from '../../raw-with-value';
import {Container} from '../../container';

/**
 * The set of raws supported by {@link IfConditionOperation}.
 *
 * @category Expression
 */
export interface IfConditionOperationRaws {
  /**
   * The raws for each operator in the operation.
   *
   * `operator` is the text of the operator, which is only used if the operator
   * matches the given value. `before` is the whitespace before the operator,
   * `after` is the whitespace after it.
   */
  operators?: Array<
    | {operator?: RawWithValue<'and' | 'or'>; before?: string; after?: string}
    | undefined
  >;
}

/**
 * The initializer properties for {@link IfConditionOperation}.
 *
 * @category Expression
 */
export interface IfConditionOperationProps extends NodeProps {
  raws?: IfConditionOperationRaws;
  operator: 'and' | 'or';
  nodes: Array<AnyIfConditionExpression | IfConditionExpressionProps>;
}

// TODO: Parse strings.
/**
 * The type of new nodes that can be passed into an `if()` condition operation.
 *
 * @category Expression
 */
export type NewNodeForIfConditionOperation =
  | AnyIfConditionExpression
  | ReadonlyArray<AnyIfConditionExpression>
  | IfConditionExpressionProps
  | ReadonlyArray<IfConditionExpressionProps>
  | undefined;

/**
 * An `and` or `or` operation in an `if()` condition.
 *
 * @category Expression
 */
export class IfConditionOperation
  extends IfConditionExpression
  implements Container<AnyIfConditionExpression, NewNodeForIfConditionOperation>
{
  readonly sassType = 'if-condition-operation' as const;
  declare raws: IfConditionOperationRaws;
  declare parent: IfEntry | AnyIfConditionExpression | undefined;

  /** The boolean operator. */
  get operator(): 'and' | 'or' {
    return this._operator;
  }
  set operator(operator: 'and' | 'or') {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._operator = operator;
  }
  declare private _operator: 'and' | 'or';

  get nodes(): ReadonlyArray<AnyIfConditionExpression> {
    return this._nodes!;
  }
  /** @hidden */
  set nodes(nodes: Array<AnyIfConditionExpression>) {
    // This *should* only ever be called by the superclass constructor.
    this._nodes = nodes;
  }
  declare private _nodes?: Array<AnyIfConditionExpression>;

  /**
   * Iterators that are currently active within this operation. Their indices
   * refer to the last position that has already been sent to the callback, and
   * are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults: IfConditionOperationProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfConditionOperation);
  constructor(defaults?: object, inner?: sassInternal.IfConditionOperation) {
    if (defaults && !('nodes' in defaults)) {
      defaults = {nodes: defaults};
    }
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.nodes = [];
      for (const expression of inner.expressions) {
        this.append(convertIfConditionExpression(expression));
      }
      this.operator = inner.op.toString() as 'and' | 'or';
    }
    this.nodes ??= [];
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfConditionOperationProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'operator', 'nodes']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['operator', 'nodes'], inputs);
  }

  append(...nodes: NewNodeForIfConditionOperation[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._nodes!.push(...this._normalizeList(nodes));
    return this;
  }

  each(
    callback: (node: AnyIfConditionExpression, index: number) => false | void,
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
      node: AnyIfConditionExpression,
      index: number,
      nodes: ReadonlyArray<AnyIfConditionExpression>,
    ) => boolean,
  ): boolean {
    return this.nodes.every(condition);
  }

  index(child: AnyIfConditionExpression | number): number {
    return typeof child === 'number' ? child : this.nodes.indexOf(child);
  }

  insertAfter(
    oldNode: AnyIfConditionExpression | number,
    newNode: NewNodeForIfConditionOperation,
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
    oldNode: AnyIfConditionExpression | number,
    newNode: NewNodeForIfConditionOperation,
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

  prepend(...nodes: NewNodeForIfConditionOperation[]): this {
    // TODO - postcss/postcss#1957: Mark this as dirty
    const normalized = this._normalizeList(nodes);
    this._nodes!.unshift(...normalized);

    for (const iterator of this.#iterators) {
      iterator.index += normalized.length;
    }

    return this;
  }

  push(child: AnyIfConditionExpression): this {
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

  removeChild(child: AnyIfConditionExpression | number): this {
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
      node: AnyIfConditionExpression,
      index: number,
      nodes: ReadonlyArray<AnyIfConditionExpression>,
    ) => boolean,
  ): boolean {
    return this.nodes.some(condition);
  }

  get first(): AnyIfConditionExpression | undefined {
    return this.nodes[0];
  }

  get last(): AnyIfConditionExpression | undefined {
    return this.nodes[this.nodes.length - 1];
  }

  /** @hidden */
  toString(): string {
    let result = '';
    const rawOperators = this.raws.operators;
    for (let i = 0; i < this.nodes.length; i++) {
      const element = this.nodes[i];
      result += element;

      if (i < this.nodes.length - 1) {
        const raw = rawOperators?.[i];
        result +=
          (raw?.before ?? ' ') +
          ((raw?.operator?.value === this.operator
            ? raw?.operator.raw
            : null) ?? this.operator) +
          (raw?.after ?? ' ');
      }
    }
    return result;
  }

  /**
   * Normalizes the many types of node that can be used with Interpolation
   * methods.
   */
  private _normalize(
    nodes: NewNodeForIfConditionOperation,
  ): AnyIfConditionExpression[] {
    const result: Array<AnyIfConditionExpression> = [];
    for (const node of Array.isArray(nodes) ? nodes : [nodes]) {
      if (node === undefined) {
        continue;
      } else {
        const constructed = fromProps(node);
        constructed.parent = this;
        result.push(constructed);
      }
    }
    return result;
  }

  /** Like {@link _normalize}, but also flattens a list of nodes. */
  private _normalizeList(
    nodes: ReadonlyArray<NewNodeForIfConditionOperation>,
  ): AnyIfConditionExpression[] {
    const result: Array<AnyIfConditionExpression> = [];
    for (const node of nodes) {
      result.push(...this._normalize(node));
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyIfConditionExpression> {
    return this.nodes;
  }
}
