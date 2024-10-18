// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {
  ConfiguredVariable,
  ConfiguredVariableExpressionProps,
  ConfiguredVariableProps,
} from './configured-variable';
import {LazySource} from './lazy-source';
import {Node} from './node';
import type * as sassInternal from './sass-internal';
import * as utils from './utils';
import {UseRule} from './statement/use-rule';

/**
 * The set of raws supported by {@link Configuration}.
 *
 * @category Statement
 */
export interface ConfigurationRaws {
  /** Whether the final variable has a trailing comma. */
  comma?: boolean;

  /**
   * The whitespace between the final variable (or its trailing comma if it has
   * one) and the closing parenthesis.
   */
  after?: string;
}

/**
 * The initializer properties for {@link Configuration}.
 *
 * @category Statement
 */
export interface ConfigurationProps {
  raws?: ConfigurationRaws;
  variables:
    | Record<string, ConfiguredVariableExpressionProps>
    | Array<ConfiguredVariable | ConfiguredVariableProps>;
}

/**
 * A configuration map for a `@use` or `@forward` rule.
 *
 * @category Statement
 */
export class Configuration extends Node {
  readonly sassType = 'configuration' as const;
  declare raws: ConfigurationRaws;
  declare parent: UseRule | undefined; // TODO: forward as well

  /** The underlying map from variable names to their values. */
  private _variables: Map<string, ConfiguredVariable> = new Map();

  /** The number of variables in this configuration. */
  get size(): number {
    return this._variables.size;
  }

  constructor(defaults?: ConfigurationProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ConfiguredVariable[]);
  constructor(
    defaults?: ConfigurationProps,
    inner?: sassInternal.ConfiguredVariable[]
  ) {
    super({});
    this.raws = defaults?.raws ?? {};

    if (defaults) {
      for (const variable of Array.isArray(defaults.variables)
        ? defaults.variables
        : Object.entries(defaults.variables)) {
        this.add(variable);
      }
    } else if (inner) {
      this.source = new LazySource({
        get span(): sassInternal.FileSpan {
          // TODO: expand inner[0] and inner.at(-1) out through `(` and `)`
          // respectively and then combine them.
          throw new Error('currently unsupported');
        },
      });
      for (const variable of inner) {
        this.add(new ConfiguredVariable(undefined, variable));
      }
    }
  }

  /**
   * Adds {@link variable} to this configuration.
   *
   * If there's already a variable with that name, it's removed first.
   */
  add(variable: ConfiguredVariable | ConfiguredVariableProps): this {
    const realVariable =
      'sassType' in variable ? variable : new ConfiguredVariable(variable);
    realVariable.parent = this;
    const old = this._variables.get(realVariable.variableName);
    if (old) old.parent = undefined;
    this._variables.set(realVariable.variableName, realVariable);
    return this;
  }

  /** Removes all variables from this configuration. */
  clear(): void {
    for (const variable of this._variables.values()) {
      variable.parent = undefined;
    }
    this._variables.clear();
  }

  /** Removes the variable named {@link name} from this configuration. */
  delete(key: string): boolean {
    const old = this._variables.get(key);
    if (old) old.parent = undefined;
    return this._variables.delete(key);
  }

  /**
   * Returns the variable named {@link name} from this configuration if it
   * contains one.
   */
  get(key: string): ConfiguredVariable | undefined {
    return this._variables.get(key);
  }

  /**
   * Returns whether this configuration has a variable named {@link name}.
   */
  has(key: string): boolean {
    return this._variables.has(key);
  }

  /**
   * Sets the variable named {@link key}. This fully overrides the previous
   * value, so all previous raws and guarded state are discarded.
   */
  set(key: string, expression: ConfiguredVariableExpressionProps): this {
    const variable = new ConfiguredVariable([key, expression]);
    variable.parent = this;
    const old = this._variables.get(key);
    if (old) old.parent = undefined;
    this._variables.set(key, variable);
    return this;
  }

  /** Returns all the variables in this configuration. */
  variables(): IterableIterator<ConfiguredVariable> {
    return this._variables.values();
  }

  clone(overrides?: Partial<ConfigurationProps>): Configuration {
    // We can't use `utils.cloneNode` here because variables isn't a public
    // field. Fortunately this class doesn't have any settable derived fields to
    // make cloning more complicated.
    return new Configuration({
      raws: overrides?.raws ?? structuredClone(this.raws),
      variables: overrides?.variables ?? [...this._variables.values()],
    });
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['variables'], inputs);
  }

  /** @hidden */
  toString(): string {
    let result = '(';
    let first = true;
    for (const variable of this._variables.values()) {
      if (first) {
        result += variable.raws.before ?? '';
        first = false;
      } else {
        result += ',';
        result += variable.raws.before ?? ' ';
      }
      result += variable.toString();
      result += variable.raws.afterValue ?? '';
    }
    return result + `${this.raws.comma ? ',' : ''}${this.raws.after ?? ''})`;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<ConfiguredVariable> {
    return [...this.variables()];
  }
}
