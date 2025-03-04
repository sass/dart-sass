// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Expression, ExpressionProps} from './expression';
import {fromProps} from './expression/from-props';
import {Node, NodeProps} from './node';
import {ArgumentList} from './argument-list';
import * as sassInternal from './sass-internal';
import {RawWithValue} from './raw-with-value';
import * as utils from './utils';

/**
 * The set of raws supported by {@link Argument}.
 *
 * @category Expression
 */
export interface ArgumentRaws {
  /**
   * The whitespace before the argument name (if it has one) or value (if it
   * doesn't).
   */
  before?: string;

  /**
   * The argument's name, not including the `$`.
   *
   * This may be different than {@link Argument.name} if the name contains
   * escape codes or underscores. It's ignored unless {@link Argument.name} is
   * defined.
   */
  name?: RawWithValue<string>;

  /**
   * The whitespace and colon between the argument name and its value. This is
   * ignored unless the argument {@link Argument.name} is defined.
   */
  between?: string;

  /**
   * The whitespace between the argument and the `...`, if {@link
   * Argument.rest} is true.
   */
  beforeRest?: string;

  /**
   * The space symbols between the end of the argument value and the comma
   * afterwards. Always empty for an argument that doesn't have a trailing comma.
   */
  after?: string;
}

/**
 * The initializer properties for {@link Argument} passed as an
 * options object.
 *
 * @category Expression
 */
export type ArgumentObjectProps = NodeProps & {
  raws?: ArgumentRaws;
  value: Expression | ExpressionProps;
} & ({name?: string; rest?: never} | {name?: never; rest?: boolean});

/**
 * Properties used to initialize a {@link Argument} without an explicit name.
 * This is used when the name is given elsewhere, either in the array form of
 * {@link ArgumentProps} or the record form of [@link
 * ArgumentDeclarationProps}.
 */
export type ArgumentExpressionProps =
  | Expression
  | ExpressionProps
  | Omit<ArgumentObjectProps, 'name'>;

/**
 * The initializer properties for {@link Argument}.
 *
 * @category Expression
 */
export type ArgumentProps =
  | ArgumentObjectProps
  | Expression
  | ExpressionProps
  | [string, ArgumentExpressionProps];

/**
 * A single argument passed to an `@include` or `@content` rule or a function
 * invocation. This is always included in a {@link ArgumentList}.
 *
 * @category Expression
 */
export class Argument extends Node {
  readonly sassType = 'argument' as const;
  declare raws: ArgumentRaws;
  declare parent: ArgumentList | undefined;

  /**
   * The argument name, not including `$`.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   *
   * Setting this to a value automatically sets {@link rest} to
   * `undefined`.
   */
  get name(): string | undefined {
    return this._name;
  }
  set name(name: string | undefined) {
    if (name) this._rest = undefined;
    this._name = name;
  }
  private declare _name?: string;

  /** The argument's value. */
  get value(): Expression {
    return this._value!;
  }
  set value(value: Expression | ExpressionProps) {
    if (this._value) this._value.parent = undefined;
    if (!('sassType' in value)) value = fromProps(value);
    if (value) value.parent = this;
    this._value = value;
  }
  private declare _value?: Expression;

  /**
   * Whether this is a rest argument (indicated by `...` in Sass).
   *
   * Setting this to true automatically sets {@link name} to
   * `undefined`.
   */
  get rest(): boolean {
    return this._rest ?? false;
  }
  set rest(value: boolean) {
    if (value) this._name = undefined;
    this._rest = value;
  }
  private declare _rest?: boolean;

  constructor(defaults: ArgumentProps) {
    if (Array.isArray(defaults)) {
      const [name, props] = defaults;
      if ('sassType' in props || !('value' in props)) {
        defaults = {
          name,
          value: props as Expression | ExpressionProps,
        };
      } else {
        defaults = {name, ...props} as ArgumentObjectProps;
      }
    } else if ('sassType' in defaults || !('value' in defaults)) {
      defaults = {
        value: defaults as Expression | ExpressionProps,
      };
    }
    super(defaults);
    this.raws ??= {};
  }

  clone(overrides?: Partial<ArgumentObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'name', explicitUndefined: true},
      'value',
      'rest',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['name', 'value', 'rest'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      (this.name === undefined
        ? ''
        : '$' +
          (this.raws.name?.value === this.name
            ? this.raws.name!.raw
            : sassInternal.toCssIdentifier(this.name)) +
          (this.raws.between ?? ': ')) +
      this.value +
      (this.rest ? (this.raws.beforeRest ?? '') + '...' : '')
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.value];
  }
}
