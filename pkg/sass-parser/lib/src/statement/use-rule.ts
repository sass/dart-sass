// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {Configuration, ConfigurationProps} from '../configuration';
import {Expression} from '../expression';
import {StringExpression} from '../expression/string';
import {LazySource} from '../lazy-source';
import {RawWithValue} from '../raw-with-value';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {ContainerProps, Statement, StatementWithChildren} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link UseRule}.
 *
 * @category Statement
 */
export interface UseRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /** The representation of {@link UseRule.url}. */
  url?: RawWithValue<string>;

  /**
   * The text of the explicit namespace value, including `as` and any whitespace
   * before it.
   *
   * Only used if {@link namespace.value} matches {@link UseRule.namespace}.
   */
  namespace?: RawWithValue<string | null>;

  /**
   * The whitespace between the URL or namespace and the `with` keyword.
   *
   * Unused if the rule doesn't have a `with` clause.
   */
  beforeWith?: string;

  /**
   * The whitespace between the `with` keyword and the configuration map.
   *
   * Unused unless the rule has a non-empty configuration.
   */
  afterWith?: string;
}

/**
 * The initializer properties for {@link UseRule}.
 *
 * @category Statement
 */
export type UseRuleProps = ContainerProps & {
  raws?: UseRuleRaws;
  useUrl: string;
  namespace?: string | null;
  configuration?: Configuration | ConfigurationProps;
};

/**
 * A `@use` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class UseRule
  extends _AtRule<Partial<UseRuleProps>>
  implements Statement
{
  readonly sassType = 'use-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: UseRuleRaws;
  declare readonly nodes: undefined;

  /** The URL loaded by the `@use` rule. */
  declare useUrl: string;

  /**
   * This rule's namespace, or `null` if the members can be accessed without a
   * namespace.
   *
   * Note that this is the _semantic_ namespace for the rule, so it's set even
   * if the namespace is inferred from the URL. When constructing a new
   * `UseRule`, this is set to {@link defaultNamespace} by default unless an
   * explicit `null` or string value is passed.
   */
  declare namespace: string | null;

  /**
   * The default namespace for {@link useUrl} if no explicit namespace is
   * specified, or null if there's not a valid default.
   */
  get defaultNamespace(): string | null {
    // Use a bogus base URL so we can parse relative URLs.
    const url = new URL(this.useUrl, 'https://example.org/');
    const basename = url.pathname.split('/').at(-1)!;
    const dot = basename.indexOf('.');
    return sassInternal.parseIdentifier(
      dot === -1 ? basename : basename.substring(0, dot)
    );
  }

  get name(): string {
    return 'use';
  }
  set name(value: string) {
    throw new Error("UseRule.name can't be overwritten.");
  }

  get params(): string {
    let result =
      this.raws.url?.value === this.useUrl
        ? this.raws.url!.raw
        : new StringExpression({text: this.useUrl, quotes: true}).toString();
    const hasConfiguration = this.configuration.size > 0;
    if (this.raws.namespace?.value === this.namespace) {
      result += this.raws.namespace?.raw;
    } else if (!this.namespace) {
      result += ' as *';
    } else if (this.defaultNamespace !== this.namespace) {
      result += ' as ' + sassInternal.toCssIdentifier(this.namespace);
    }

    if (hasConfiguration) {
      result +=
        `${this.raws.beforeWith ?? ' '}with` +
        `${this.raws.afterWith ?? ' '}${this.configuration}`;
    }
    return result;
  }
  set params(value: string | number | undefined) {
    throw new Error("UseRule.params can't be overwritten.");
  }

  /** The variables whose defaults are set when loading this module. */
  get configuration(): Configuration {
    return this._configuration!;
  }
  set configuration(configuration: Configuration | ConfigurationProps) {
    if (this._configuration) {
      this._configuration.clear();
      this._configuration.parent = undefined;
    }
    this._configuration =
      'sassType' in configuration
        ? configuration
        : new Configuration(configuration);
    this._configuration.parent = this;
  }
  private _configuration!: Configuration;

  constructor(defaults: UseRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.UseRule);
  constructor(defaults?: UseRuleProps, inner?: sassInternal.UseRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.useUrl = inner.url.toString();
      this.namespace = inner.namespace ?? null;
      this.configuration = new Configuration(undefined, inner.configuration);
    } else {
      this.configuration ??= new Configuration();
      if (this.namespace === undefined) this.namespace = this.defaultNamespace;
    }
  }

  clone(overrides?: Partial<UseRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'useUrl',
      'namespace',
      'configuration',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['useUrl', 'namespace', 'configuration', 'params'],
      inputs
    );
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [...Object.values(this.configuration)];
  }
}

interceptIsClean(UseRule);
