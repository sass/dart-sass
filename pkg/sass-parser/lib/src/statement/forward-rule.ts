// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {Configuration, ConfigurationProps} from '../configuration';
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
 * A list of member names that are shown or hidden by a {@link ForwardRule}. At
 * least one of {@link mixinsAndFunctions} or {@link variables} must contain at
 * least one element, or this can't be represented as Sass source code.
 *
 * @category Statement
 */
export interface ForwardMemberList {
  /** Mixin and function names to show or hide. */
  mixinsAndFunctions: Set<string>;

  /** Variable names to show or hide, without `$`. */
  variables: Set<string>;
}

/**
 * The set of raws supported by {@link ForwardRule}.
 *
 * @category Statement
 */
export interface ForwardRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /** The representation of {@link ForwardRule.forwardUrl}. */
  url?: RawWithValue<string>;

  /**
   * The text of the added prefix, including `as` and any whitespace before it.
   *
   * Only used if {@link prefix.value} matches {@link ForwardRule.prefix}.
   */
  prefix?: RawWithValue<string>;

  /**
   * The text of the list of members to forward, including `show` and any
   * whitespace before it.
   *
   * Only used if {@link show.value} matches {@link ForwardRule.show}.
   */
  show?: RawWithValue<ForwardMemberList>;

  /**
   * The text of the list of members not to forward, including `hide` and any
   * whitespace before it.
   *
   * Only used if {@link hide.value} matches {@link ForwardRule.hide}.
   */
  hide?: RawWithValue<ForwardMemberList>;

  /**
   * The whitespace between the URL or prefix and the `with` keyword.
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

/** The initializer properties for {@link ForwardMemberList}. */
export interface ForwardMemberProps {
  mixinsAndFunctions?: Iterable<string>;
  variables?: Iterable<string>;
}

/**
 * The initializer properties for {@link ForwardRule}.
 *
 * @category Statement
 */
export type ForwardRuleProps = ContainerProps & {
  raws?: ForwardRuleRaws;
  forwardUrl: string;
  prefix?: string;
  configuration?: Configuration | ConfigurationProps;
} & (
    | {show?: ForwardMemberProps; hide?: never}
    | {hide?: ForwardMemberProps; show?: never}
  );

/**
 * A `@forward` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ForwardRule
  extends _AtRule<Partial<ForwardRuleProps>>
  implements Statement
{
  readonly sassType = 'forward-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ForwardRuleRaws;
  declare readonly nodes: undefined;

  /** The URL loaded by the `@forward` rule. */
  declare forwardUrl: string;

  /**
   * The prefix added to the beginning of mixin, variable, and function names
   * loaded by this rule. Defaults to ''.
   */
  declare prefix: string;

  /**
   * The allowlist of names of members to forward from the loaded module.
   *
   * If this is defined, {@link hide} must be undefined. If this and {@link
   * hide} are both undefined, all members are forwarded.
   *
   * Setting this to a non-`undefined` value automatically sets {@link hide} to
   * `undefined`.
   */
  get show(): ForwardMemberList | undefined {
    return this._show;
  }
  set show(value: ForwardMemberProps | undefined) {
    if (value) {
      this._hide = undefined;
      this._show = {
        mixinsAndFunctions: new Set([...(value.mixinsAndFunctions ?? [])]),
        variables: new Set([...(value.variables ?? [])]),
      };
    } else {
      this._show = undefined;
    }
  }
  declare _show?: ForwardMemberList;

  /**
   * The blocklist of names of members to forward from the loaded module.
   *
   * If this is defined, {@link show} must be undefined. If this and {@link
   * show} are both undefined, all members are forwarded.
   *
   * Setting this to a non-`undefined` value automatically sets {@link show} to
   * `undefined`.
   */
  get hide(): ForwardMemberList | undefined {
    return this._hide;
  }
  set hide(value: ForwardMemberProps | undefined) {
    if (value) {
      this._show = undefined;
      this._hide = {
        mixinsAndFunctions: new Set([...(value.mixinsAndFunctions ?? [])]),
        variables: new Set([...(value.variables ?? [])]),
      };
    } else {
      this._hide = undefined;
    }
  }
  declare _hide?: ForwardMemberList;

  get name(): string {
    return 'forward';
  }
  set name(value: string) {
    throw new Error("ForwardRule.name can't be overwritten.");
  }

  get params(): string {
    let result =
      this.raws.url?.value === this.forwardUrl
        ? this.raws.url!.raw
        : new StringExpression({
            text: this.forwardUrl,
            quotes: true,
          }).toString();

    if (this.raws.prefix?.value === this.prefix) {
      result += this.raws.prefix?.raw;
    } else if (this.prefix) {
      result += ` as ${sassInternal.toCssIdentifier(this.prefix)}*`;
    }

    if (this.show) {
      result += this._serializeMemberList('show', this.show, this.raws.show);
    } else if (this.hide) {
      result += this._serializeMemberList('hide', this.hide, this.raws.hide);
    }

    const hasConfiguration = this.configuration.size > 0;
    if (hasConfiguration) {
      result +=
        `${this.raws.beforeWith ?? ' '}with` +
        `${this.raws.afterWith ?? ' '}${this.configuration}`;
    }
    return result;
  }
  set params(value: string | number | undefined) {
    throw new Error("ForwardRule.params can't be overwritten.");
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
  private declare _configuration: Configuration;

  constructor(defaults: ForwardRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ForwardRule);
  constructor(defaults?: ForwardRuleProps, inner?: sassInternal.ForwardRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.forwardUrl = inner.url.toString();
      this.prefix = inner.prefix ?? '';
      if (inner.shownMixinsAndFunctions) {
        this.show = {
          mixinsAndFunctions: sassInternal.setToJS(
            inner.shownMixinsAndFunctions,
          ),
          variables: sassInternal.setToJS(inner.shownVariables!),
        };
      } else if (inner.hiddenMixinsAndFunctions) {
        this.hide = {
          mixinsAndFunctions: sassInternal.setToJS(
            inner.hiddenMixinsAndFunctions,
          ),
          variables: sassInternal.setToJS(inner.hiddenVariables!),
        };
      }
      this.configuration = new Configuration(undefined, inner.configuration);
    } else {
      this.configuration ??= new Configuration();
      this.prefix ??= '';
    }
  }

  /**
   * Serializes {@link members} to string, respecting {@link raws} if it's
   * defined and matches.
   */
  private _serializeMemberList(
    keyword: string,
    members: ForwardMemberList,
    raws: RawWithValue<ForwardMemberList> | undefined,
  ): string {
    if (this._memberListsEqual(members, raws?.value)) return raws!.raw;
    const mixinsAndFunctionsEmpty = members.mixinsAndFunctions.size === 0;
    const variablesEmpty = members.variables.size === 0;
    if (mixinsAndFunctionsEmpty && variablesEmpty) {
      throw new Error(
        'Either ForwardMemberList.mixinsAndFunctions or ' +
          'ForwardMemberList.variables must contain a name.',
      );
    }

    return (
      ` ${keyword} ` +
      [...members.mixinsAndFunctions]
        .map(name => sassInternal.toCssIdentifier(name))
        .join(', ') +
      (mixinsAndFunctionsEmpty || variablesEmpty ? '' : ', ') +
      [...members.variables]
        .map(variable => '$' + sassInternal.toCssIdentifier(variable))
        .join(', ')
    );
  }

  /**
   * Returns whether {@link list1} and {@link list2} contain the same values.
   */
  private _memberListsEqual(
    list1: ForwardMemberList | undefined,
    list2: ForwardMemberList | undefined,
  ): boolean {
    if (list1 === list2) return true;
    if (!list1 || !list2) return false;
    return (
      utils.setsEqual(list1.mixinsAndFunctions, list2.mixinsAndFunctions) &&
      utils.setsEqual(list1.variables, list2.variables)
    );
  }

  clone(overrides?: Partial<ForwardRuleProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'forwardUrl',
      'prefix',
      {name: 'show', explicitUndefined: true},
      {name: 'hide', explicitUndefined: true},
      'configuration',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['forwardUrl', 'prefix', 'configuration', 'show', 'hide', 'params'],
      inputs,
    );
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Configuration> {
    return [this.configuration];
  }
}

interceptIsClean(ForwardRule);
