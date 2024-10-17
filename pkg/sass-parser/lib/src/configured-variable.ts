// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Configuration} from './configuration';
import {convertExpression} from './expression/convert';
import {Expression, ExpressionProps} from './expression';
import {fromProps} from './expression/from-props';
import {LazySource} from './lazy-source';
import {Node} from './node';
import * as sassInternal from './sass-internal';
import {RawWithValue} from './raw-with-value';
import * as utils from './utils';

/**
 * The set of raws supported by {@link ConfiguredVariable}.
 *
 * @category Statement
 */
export interface ConfiguredVariableRaws {
  /** The whitespace before the variable name. */
  before?: string;

  /**
   * The variable's name, not including the `$`.
   *
   * This may be different than {@link ConfiguredVariable.variable} if the name
   * contains escape codes or underscores.
   */
  variable?: RawWithValue<string>;

  /** The whitespace and colon between the variable name and value. */
  between?: string;

  /**
   * The whitespace between the variable's value and the `!default` flag. If the
   * variable doesn't have a `!default` flag, this is ignored.
   */
  beforeGuard?: string;

  /**
   * The space symbols between the end of the variable declaration and the comma
   * afterwards. Always empty for a variable that doesn't have a trailing comma.
   */
  afterValue?: string;
}

/**
 * The initializer properties for {@link ConfiguredVariable} passed as an
 * options object.
 *
 * @category Statement
 */
export interface ConfiguredVariableObjectProps {
  raws?: ConfiguredVariableRaws;
  variable: string;
  expression: Expression | ExpressionProps;
  guarded?: boolean;
}

/**
 * Properties used to initialize a {@link ConfiguredVariable} without an
 * explicit name. This is used when the name is given elsewhere, either in the
 * array form of {@link ConfiguredVariableProps} or the record form of [@link
 * ConfigurationProps}.
 *
 * Passing in an {@link Expression} or {@link ExpressionProps} directly always
 * creates an unguarded {@link ConfiguredVariable}.
 */
export type ConfiguredVariableExpressionProps =
  | Expression
  | ExpressionProps
  | Omit<ConfiguredVariableObjectProps, 'variable'>;

/**
 * The initializer properties for {@link ConfiguredVariable}.
 *
 * @category Statement
 */
export type ConfiguredVariableProps =
  | ConfiguredVariableObjectProps
  | [string, ConfiguredVariableExpressionProps];

/**
 * A single variable configured for the `with` clause of a `@use` or `@forward`
 * rule. This is always included in a {@link Configuration}.
 *
 * @category Statement
 */
export class ConfiguredVariable extends Node {
  readonly sassType = 'configured-variable' as const;
  declare raws: ConfiguredVariableRaws;
  declare parent: Configuration | undefined;

  /**
   * The variable name, not including `$`.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  variable!: string;

  /** The expresison whose value the variable is assigned. */
  get expression(): Expression {
    return this._expression!;
  }
  set expression(value: Expression | ExpressionProps) {
    if (this._expression) this._expression.parent = undefined;
    if (!('sassType' in value)) value = fromProps(value);
    if (value) value.parent = this;
    this._expression = value;
  }
  private _expression!: Expression;

  /** Whether this has a `!default` guard. */
  guarded!: boolean;

  constructor(defaults: ConfiguredVariableProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ConfiguredVariable);
  constructor(
    defaults?: ConfiguredVariableProps,
    inner?: sassInternal.ConfiguredVariable
  ) {
    if (Array.isArray(defaults!)) {
      const [variable, rest] = defaults;
      if ('sassType' in rest || !('expression' in rest)) {
        defaults = {variable, expression: rest as Expression | ExpressionProps};
      } else {
        defaults = {variable, ...rest};
      }
    }
    super(defaults);

    if (inner) {
      this.source = new LazySource(inner!);
      this.variable = inner!.name;
      this.expression = convertExpression(inner.expression);
      this.guarded = inner.isGuarded;
    } else {
      this.guarded ??= false;
    }

    this.raws ??= {};
  }

  clone(overrides?: Partial<ConfiguredVariableObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'variable',
      'expression',
      'guarded',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['variable', 'expression', 'guarded'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      '$' +
      (this.raws.variable?.value === this.variable
        ? this.raws.variable.raw
        : sassInternal.toCssIdentifier(this.variable)) +
      (this.raws.between ?? ': ') +
      this.expression +
      (this.guarded ? `${this.raws.beforeGuard ?? ' '}!default` : '')
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.expression];
  }
}
