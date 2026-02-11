// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {NodeProps} from '../../node';
import type * as sassInternal from '../../sass-internal';
import * as utils from '../../utils';
import {AnyIfConditionExpression, IfConditionExpression} from './index';
import {IfEntry} from '../if-entry';
import {LazySource} from '../../lazy-source';
import {Interpolation, InterpolationProps} from '../../interpolation';

/**
 * The set of raws supported by {@link IfConditionFunction}.
 *
 * @category Expression
 */
export interface IfConditionFunctionRaws {
  /** The whitespace between the opening parenthesis and the argument. */
  afterOpen?: string;

  /** The whitespace between the argument and the closing parenthesis. */
  beforeClose?: string;
}

/**
 * The initializer properties for {@link IfConditionFunction}.
 *
 * @category Expression
 */
export interface IfConditionFunctionProps extends NodeProps {
  raws?: IfConditionFunctionRaws;
  name: Interpolation | InterpolationProps;
  argument: Interpolation | InterpolationProps;
}

/**
 * A CSS function condition in an `if()` condition.
 *
 * @category Expression
 */
export class IfConditionFunction extends IfConditionExpression {
  readonly sassType = 'if-condition-function' as const;
  declare raws: IfConditionFunctionRaws;
  declare parent: IfEntry | AnyIfConditionExpression | undefined;

  /** The function's name. */
  get name(): Interpolation {
    return this._name!;
  }
  set name(name: Interpolation | InterpolationProps) {
    if (this._name) this._name.parent = undefined;
    const built =
      typeof name === 'object' && 'sassType' in name
        ? name
        : new Interpolation(name);
    built.parent = this;
    this._name = built;
  }
  declare private _name?: Interpolation;

  /** The function's argument or arguments. */
  get argument(): Interpolation {
    return this._argument!;
  }
  set argument(argument: Interpolation | InterpolationProps) {
    if (this._argument) this._argument.parent = undefined;
    const built =
      typeof argument === 'object' && 'sassType' in argument
        ? argument
        : new Interpolation(argument);
    built.parent = this;
    this._argument = built;
  }
  declare private _argument?: Interpolation;

  constructor(defaults: IfConditionFunctionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfConditionFunction);
  constructor(defaults?: object, inner?: sassInternal.IfConditionFunction) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.name = new Interpolation(undefined, inner.name);
      this.argument = new Interpolation(undefined, inner.arguments);
    }
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfConditionFunctionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'name', 'argument']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['name', 'argument'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      this.name +
      '(' +
      (this.raws.afterOpen ?? '') +
      this.argument +
      (this.raws.beforeClose ?? '') +
      ')'
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    return [this.name, this.argument];
  }
}
