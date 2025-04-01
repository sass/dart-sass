// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {ArgumentList, ArgumentListProps} from '../argument-list';
import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import {RawWithValue} from '../raw-with-value';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link FunctionExpression}.
 *
 * @category Expression
 */
export interface FunctionExpressionProps extends NodeProps {
  namespace?: string;
  name: string;
  arguments: ArgumentList | ArgumentListProps;
  raws?: FunctionExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link FunctionExpression}.
 *
 * @category Expression
 */
export interface FunctionExpressionRaws {
  /**
   * The function's namespace.
   *
   * This may be different than {@link FunctionExpression.namespace} if the
   * namespace contains escape codes.
   */
  namespace?: RawWithValue<string>;

  /**
   * The function's name.
   *
   * This may be different than {@link FunctionExpression.name} if the name
   * contains escape codes or underscores.
   */
  name?: RawWithValue<string>;
}

/**
 * An expression representing a (non-interpolated) function call in Sass.
 *
 * @category Expression
 */
export class FunctionExpression extends Expression {
  readonly sassType = 'function-call' as const;
  declare raws: FunctionExpressionRaws;

  /**
   * This function's namespace.
   *
   * This is the parsed and normalized value, with escapes resolved to the
   * characters they represent.
   */
  get namespace(): string | undefined {
    return this._namespace;
  }
  set namespace(namespace: string | undefined) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._namespace = namespace;
  }
  private declare _namespace: string | undefined;

  /**
   * This function's name.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  get name(): string {
    return this._name;
  }
  set name(name: string) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._name = name;
  }
  private declare _name: string;

  /** The arguments to pass to the function. */
  get arguments(): ArgumentList {
    return this._arguments!;
  }
  set arguments(args: ArgumentList | ArgumentListProps | undefined) {
    if (this._arguments) this._arguments.parent = undefined;
    this._arguments = args
      ? 'sassType' in args
        ? args
        : new ArgumentList(args)
      : new ArgumentList();
    this._arguments.parent = this;
  }
  private declare _arguments: ArgumentList;

  constructor(defaults: FunctionExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.FunctionExpression);
  constructor(defaults?: object, inner?: sassInternal.FunctionExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.namespace = inner.namespace ?? undefined;
      this.name = inner.name;
      this.arguments = new ArgumentList(undefined, inner.arguments);
    }
  }

  clone(overrides?: Partial<FunctionExpressionProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'namespace', explicitUndefined: true},
      'name',
      'arguments',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['namespace', 'name', 'arguments'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      (this.namespace
        ? (this.raws.namespace?.value === this.namespace
            ? this.raws.namespace.raw
            : sassInternal.toCssIdentifier(this.namespace)) + '.'
        : '') +
      (this.raws.name?.value === this.name
        ? this.raws.name.raw
        : sassInternal.toCssIdentifier(this.name)) +
      this.arguments
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<ArgumentList> {
    return [this.arguments];
  }
}
