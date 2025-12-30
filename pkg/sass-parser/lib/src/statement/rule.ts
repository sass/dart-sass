// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {RuleRaws as PostcssRuleRaws} from 'postcss/lib/rule';

import {LazySource} from '../lazy-source';
import * as sassInternal from '../sass-internal';
import {SelectorList, SelectorListProps} from '../selector/list';
import * as utils from '../utils';
import {
  ChildNode,
  ContainerProps,
  NewNode,
  Statement,
  StatementWithChildren,
  appendInternalChildren,
  normalize,
} from '.';
import {interceptIsClean} from './intercept-is-clean';
import {_Rule} from './rule-internal';
import * as sassParser from '../..';

/**
 * The set of raws supported by a style rule.
 *
 * Sass doesn't support PostCSS's `params` raws, since the selector is lexed and
 * made directly available to the caller.
 *
 * @category Statement
 */
export type RuleRaws = Omit<PostcssRuleRaws, 'selector'>;

/**
 * The initializer properties for {@link Rule}.
 *
 * @category Statement
 */
export type RuleProps = ContainerProps & {raws?: RuleRaws} & (
    | {parsedSelector: SelectorList | SelectorListProps}
    | {selector: string}
    | {selectors: string[]}
  );

/**
 * A style rule. Extends [`postcss.Rule`].
 *
 * [`postcss.Rule`]: https://postcss.org/api/#rule
 *
 * @category Statement
 */
export class Rule extends _Rule implements Statement {
  readonly sassType = 'rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: RuleRaws;

  get selector(): string {
    return this.parsedSelector.toString();
  }
  set selector(value: string) {
    this.parsedSelector = {type: value};
  }

  get parsedSelector(): SelectorList {
    return this._selector!;
  }
  set parsedSelector(selector: SelectorList | SelectorListProps) {
    if (this._selector) this._selector.parent = undefined;
    const built =
      typeof selector === 'object' &&
      'sassType' in selector &&
      selector.sassType === 'selector-list'
        ? selector
        : new SelectorList(selector);
    built.parent = this;
    this._selector = built;
  }
  private declare _selector?: SelectorList;

  constructor(defaults: RuleProps);
  constructor(_: undefined, inner: sassInternal.StyleRule);
  /** @hidden */
  constructor(defaults?: RuleProps, inner?: sassInternal.StyleRule) {
    // PostCSS claims that it requires either selector or selectors, but we
    // define the former as a getter instead.
    super(defaults as postcss.RuleProps);
    if (inner) {
      this.source = new LazySource(inner);
      this.parsedSelector = new SelectorList(undefined, inner.parsedSelector);
      appendInternalChildren(this, inner.children);
    }
  }

  // TODO: Once we make selector parsing available to JS, use it to override
  // selectors() and to provide access to parsed selectors if selector is plain
  // text.

  clone(overrides?: Partial<RuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['nodes', 'raws', 'parsedSelector'],
      ['selector', 'selectors'],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['selector', 'parsedSelector', 'nodes'], inputs);
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<SelectorList> {
    return [this.parsedSelector];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(Rule);
