// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {ArgumentList, ArgumentListProps} from '../argument-list';
import {Interpolation, InterpolationProps} from '../interpolation';
import {LazySource} from '../lazy-source';
import {AnyNode, NodeProps} from '../node';
import {AnyStatement} from '../statement';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link InterpolatedFunctionExpression}.
 *
 * @category Expression
 */
export interface InterpolatedFunctionExpressionProps extends NodeProps {
  name: Interpolation | Omit<InterpolationProps, string>;
  arguments: ArgumentList | ArgumentListProps;
  raws?: InterpolatedFunctionExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link
 * InterpolatedFunctionExpression}.
 *
 * @category Expression
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for an interpolated function expression yet.
export interface InterpolatedFunctionExpressionRaws {}

/**
 * An expression representing an interpolated function call in Sass.
 *
 * @category Expression
 */
export class InterpolatedFunctionExpression extends Expression {
  readonly sassType = 'interpolated-function-call' as const;
  declare raws: InterpolatedFunctionExpressionRaws;

  /** This function's name. */
  get name(): Interpolation {
    return this._name;
  }
  set name(name: Interpolation | InterpolationProps) {
    if (this._name) this._name.parent = undefined;
    this._name =
      typeof name === 'object' && 'sassType' in name
        ? name
        : new Interpolation(name);
    this._name.parent = this;
  }
  declare private _name: Interpolation;

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
  declare private _arguments: ArgumentList;

  constructor(defaults: InterpolatedFunctionExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.InterpolatedFunctionExpression);
  constructor(
    defaults?: object,
    inner?: sassInternal.InterpolatedFunctionExpression,
  ) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.name = new Interpolation(undefined, inner.name);
      this.arguments = new ArgumentList(undefined, inner.arguments);
    }
  }

  clone(overrides?: Partial<InterpolatedFunctionExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'name', 'arguments']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['name', 'arguments'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.name.toString() + this.arguments;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [this.name, this.arguments];
  }
}
