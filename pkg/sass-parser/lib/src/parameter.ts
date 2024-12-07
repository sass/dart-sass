// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {convertExpression} from './expression/convert';
import {Expression, ExpressionProps} from './expression';
import {fromProps} from './expression/from-props';
import {LazySource} from './lazy-source';
import {Node} from './node';
import {ParameterList} from './parameter-list';
import * as sassInternal from './sass-internal';
import {RawWithValue} from './raw-with-value';
import * as utils from './utils';

/**
 * The set of raws supported by {@link Parameter}.
 *
 * @category Statement
 */
export interface ParameterRaws {
  /** The whitespace before the parameter name. */
  before?: string;

  /**
   * The parameter's name, not including the `$`.
   *
   * This may be different than {@link Parameter.name} if the name contains
   * escape codes or underscores.
   */
  name?: RawWithValue<string>;

  /**
   * The whitespace and colon between the parameter name and default value, if
   * it has one.
   */
  between?: string;

  /**
   * The whitespace between the parameter name and the `...`, if {@link
   * Parameter.rest} is true.
   */
  beforeRest?: string;

  /**
   * The space symbols between the end of the parameter (after the default value
   * if it has one or the parameter name if it doesn't) and the comma afterwards.
   * Always empty for a parameter that doesn't have a trailing comma.
   */
  after?: string;
}

/**
 * The initializer properties for {@link Parameter} passed as an
 * options object.
 *
 * @category Statement
 */
export type ParameterObjectProps = {
  raws?: ParameterRaws;
  name: string;
} & (
  | {
      defaultValue?: Expression | ExpressionProps;
      rest?: never;
    }
  | {
      defaultValue?: never;
      rest?: boolean;
    }
);

/**
 * Properties used to initialize a {@link Parameter} without an explicit name.
 * This is used when the name is given elsewhere, either in the array form of
 * {@link ParameterProps} or the record form of [@link
 * ParameterDeclarationProps}.
 */
export type ParameterExpressionProps =
  | Expression
  | ExpressionProps
  | Omit<ParameterObjectProps, 'name'>;

/**
 * The initializer properties for {@link Parameter}.
 *
 * @category Statement
 */
export type ParameterProps =
  | ParameterObjectProps
  | string
  | [string, ParameterExpressionProps];

/**
 * A single parameter defined in the parameter declaration of a `@mixin` or
 * `@function` rule. This is always included in a {@link ParameterList}.
 *
 * @category Statement
 */
export class Parameter extends Node {
  readonly sassType = 'parameter' as const;
  declare raws: ParameterRaws;
  declare parent: ParameterList | undefined;

  /**
   * The parameter name, not including `$`.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare name: string;

  /**
   * The expression that provides the default value for the parameter.
   *
   * Setting this to a value automatically sets {@link rest} to `false`.
   */
  get defaultValue(): Expression | undefined {
    return this._defaultValue!;
  }
  set defaultValue(value: Expression | ExpressionProps | undefined) {
    if (this._defaultValue) this._defaultValue.parent = undefined;
    if (!value) {
      this._defaultValue = undefined;
    } else {
      this._rest = false;
      if (!('sassType' in value)) value = fromProps(value);
      if (value) value.parent = this;
      this._defaultValue = value;
    }
  }
  private declare _defaultValue?: Expression;

  /**
   * Whether this is a rest parameter (indicated by `...` in Sass).
   *
   * Setting this to true automatically sets {@link defaultValue} to
   * `undefined`.
   */
  get rest(): boolean {
    return this._rest ?? false;
  }
  set rest(value: boolean) {
    if (value) this.defaultValue = undefined;
    this._rest = value;
  }
  private declare _rest?: boolean;

  constructor(defaults: ParameterProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.Argument);
  constructor(defaults?: ParameterProps, inner?: sassInternal.Argument) {
    if (typeof defaults === 'string') {
      defaults = {name: defaults};
    } else if (Array.isArray(defaults)) {
      const [name, props] = defaults;
      if (
        'sassType' in props ||
        !('defaultValue' in props || 'rest' in props)
      ) {
        defaults = {
          name,
          defaultValue: props as Expression | ExpressionProps,
        };
      } else {
        defaults = {name, ...props} as ParameterObjectProps;
      }
    }
    super(defaults);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.name = inner.name;
      this.defaultValue = inner.defaultValue
        ? convertExpression(inner.defaultValue)
        : undefined;
    }
  }

  clone(overrides?: Partial<ParameterObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'name',
      {name: 'defaultValue', explicitUndefined: true},
      'rest',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['name', 'defaultValue', 'rest'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      '$' +
      (this.raws.name?.value === this.name
        ? this.raws.name.raw
        : sassInternal.toCssIdentifier(this.name)) +
      (this.defaultValue
        ? (this.raws.between ?? ': ') + this.defaultValue
        : '') +
      (this.rest ? (this.raws.beforeRest ?? '') + '...' : '')
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return this.defaultValue ? [this.defaultValue] : [];
  }
}
