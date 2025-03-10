// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import {RawWithValue} from '../raw-with-value';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link VariableExpression}.
 *
 * @category Expression
 */
export interface VariableExpressionProps extends NodeProps {
  namespace?: string;
  variableName: string;
  raws?: VariableExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link VariableExpression}.
 *
 * @category Expression
 */
export interface VariableExpressionRaws {
  /**
   * The variable's namespace.
   *
   * This may be different than {@link VariableExpression.namespace} if the
   * namespace contains escape codes.
   */
  namespace?: RawWithValue<string>;

  /**
   * The variable's name.
   *
   * This may be different than {@link VariableExpression.varialbeName} if the
   * name contains escape codes or underscores.
   */
  variableName?: RawWithValue<string>;
}

/**
 * An expression representing a variable reference in Sass.
 *
 * @category Expression
 */
export class VariableExpression extends Expression {
  readonly sassType = 'variable' as const;
  declare raws: VariableExpressionRaws;

  /**
   * This variable's namespace.
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
   * This variable's name.
   *
   * This is the parsed and normalized value, with underscores converted to
   * hyphens and escapes resolved to the characters they represent.
   */
  get variableName(): string {
    return this._variableName;
  }
  set variableName(variableName: string) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._variableName = variableName;
  }
  private declare _variableName: string;

  constructor(defaults: VariableExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.VariableExpression);
  constructor(defaults?: object, inner?: sassInternal.VariableExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.namespace = inner.namespace ?? undefined;
      this.variableName = inner.name;
    }
  }

  clone(overrides?: Partial<VariableExpressionProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'namespace', explicitUndefined: true},
      'variableName',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['namespace', 'variableName'], inputs);
  }

  /** @hidden */
  toString(): string {
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

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<never> {
    return [];
  }
}
