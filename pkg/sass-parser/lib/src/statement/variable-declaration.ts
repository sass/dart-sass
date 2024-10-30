// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {DeclarationRaws} from 'postcss/lib/declaration';

import {Expression, ExpressionProps} from '../expression';
import {convertExpression} from '../expression/convert';
import {fromProps} from '../expression/from-props';
import {LazySource} from '../lazy-source';
import {RawWithValue} from '../raw-with-value';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Statement, StatementWithChildren} from '.';
import {_Declaration} from './declaration-internal';

/**
 * The set of raws supported by {@link VariableDeclaration}.
 *
 * @category Statement
 */
export interface VariableDeclarationRaws
  extends Omit<DeclarationRaws, 'value' | 'important'> {
  /**
   * The variable's namespace.
   *
   * This may be different than {@link VariableDeclarationRaws.namespace} if the
   * name contains escape codes or underscores.
   */
  namespace?: RawWithValue<string>;

  /**
   * The variable's name, not including the `$`.
   *
   * This may be different than {@link VariableDeclarationRaws.variableName} if
   * the name contains escape codes or underscores.
   */
  variableName?: RawWithValue<string>;

  /** The whitespace and colon between the variable name and value. */
  between?: string;

  /** The `!default` and/or `!global` flags, including preceding whitespace. */
  flags?: RawWithValue<{guarded: boolean; global: boolean}>;

  /**
   * The space symbols between the end of the variable declaration and the
   * semicolon afterwards. Always empty for a variable that isn't followed by a
   * semicolon.
   */
  afterValue?: string;
}

/**
 * The initializer properties for {@link VariableDeclaration}.
 *
 * @category Statement
 */
export type VariableDeclarationProps = {
  raws?: VariableDeclarationRaws;
  namespace?: string;
  variableName: string;
  guarded?: boolean;
  global?: boolean;
} & ({expression: Expression | ExpressionProps} | {value: string});

/**
 * A Sass variable declaration. Extends [`postcss.Declaration`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#declaration
 *
 * @category Statement
 */
export class VariableDeclaration
  extends _Declaration<Partial<VariableDeclarationProps>>
  implements Statement
{
  readonly sassType = 'variable-declaration' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: VariableDeclarationRaws;

  /**
   * The variable name, not including `$`.
   *
   * This is the parsed value, with escapes resolved to the characters they
   * represent.
   */
  declare namespace: string | undefined;

  /**
   * The variable name, not including `$`.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  declare variableName: string;

  /** The variable's value. */
  get expression(): Expression {
    return this._expression;
  }
  set expression(value: Expression | ExpressionProps) {
    if (this._expression) this._expression.parent = undefined;
    if (!('sassType' in value)) value = fromProps(value);
    if (value) value.parent = this;
    this._expression = value;
  }
  private _expression!: Expression;

  /** Whether the variable has a `!default` flag. */
  declare guarded: boolean;

  /** Whether the variable has a `!global` flag. */
  declare global: boolean;

  get prop(): string {
    return (
      (this.namespace
        ? (this.raws.namespace?.value === this.namespace
            ? this.raws.namespace.raw
            : sassInternal.toCssIdentifier(this.namespace)) + '.'
        : '') +
      '$' +
      (this.raws.variableName?.value === this.variableName
        ? this.raws.variableName.raw
        : sassInternal.toCssIdentifier(this.variableName))
    );
  }
  set prop(value: string) {
    throw new Error("VariableDeclaration.prop can't be overwritten.");
  }

  get value(): string {
    return this.expression.toString();
  }
  set value(value: string) {
    this.expression = {text: value};
  }

  get important(): boolean {
    // TODO: Return whether `this.expression` is a nested series of unbracketed
    // list expressions that ends in the unquoted string `!important` (or an
    // unquoted string ending in " !important", which can occur if `value` is
    // set // manually).
    throw new Error('Not yet implemented');
  }
  set important(value: boolean) {
    // TODO: If value !== this.important, either set this to a space-separated
    // list whose second value is `!important` or remove the existing
    // `!important` from wherever it's defined. Or if that's too complex, just
    // bake this to a string expression and edit that.
    throw new Error('Not yet implemented');
  }

  get variable(): boolean {
    return true;
  }

  constructor(defaults: VariableDeclarationProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.VariableDeclaration);
  constructor(
    defaults?: VariableDeclarationProps,
    inner?: sassInternal.VariableDeclaration
  ) {
    super(defaults as unknown as postcss.DeclarationProps);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.namespace = inner.namespace ? inner.namespace : undefined;
      this.variableName = inner.name;
      this.expression = convertExpression(inner.expression);
      this.guarded = inner.isGuarded;
      this.global = inner.isGlobal;
    } else {
      this.guarded ??= false;
      this.global ??= false;
    }
  }

  clone(overrides?: Partial<VariableDeclarationProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      [
        'raws',
        {name: 'namespace', explicitUndefined: true},
        'variableName',
        'expression',
        'guarded',
        'global',
      ],
      ['value']
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['namespace', 'variableName', 'expression', 'guarded', 'global'],
      inputs
    );
  }

  /** @hidden */
  toString(): string {
    return (
      this.prop +
      (this.raws.between ?? ': ') +
      this.expression +
      (this.raws.flags?.value?.guarded === this.guarded &&
      this.raws.flags?.value?.global === this.global
        ? this.raws.flags.raw
        : (this.guarded ? ' !default' : '') + (this.global ? ' !global' : '')) +
      (this.raws.afterValue ?? '')
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.expression];
  }
}
