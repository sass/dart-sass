// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {ArgumentList, ArgumentListProps} from '../argument-list';
import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Statement, StatementWithChildren} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link ContentRule}.
 *
 * @category Statement
 */
export interface ContentRuleRaws extends Omit<AtRuleRaws, 'params'> {
  /**
   * Whether to content an empty argument list. If the argument list isn't
   * empty, this is ignored.
   */
  showArguments?: boolean;
}

/**
 * The initializer properties for {@link ContentRule}.
 *
 * @category Statement
 */
export interface ContentRuleProps extends NodeProps {
  raws?: ContentRuleRaws;
  contentArguments?: ArgumentList | ArgumentListProps;
}

/**
 * An `@content` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ContentRule
  extends _AtRule<Partial<ContentRuleProps>>
  implements Statement
{
  readonly sassType = 'content-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ContentRuleRaws;
  declare readonly nodes: undefined;

  /** The arguments to pass to the mixin invocation's `using` block. */
  get contentArguments(): ArgumentList {
    return this._contentArguments!;
  }
  set contentArguments(args: ArgumentList | ArgumentListProps | undefined) {
    if (this._contentArguments) {
      this._contentArguments.parent = undefined;
    }
    this._contentArguments = args
      ? 'sassType' in args
        ? args
        : new ArgumentList(args)
      : new ArgumentList();
    this._contentArguments.parent = this;
  }
  private declare _contentArguments: ArgumentList;

  get name(): string {
    return 'content';
  }
  set name(value: string) {
    throw new Error("ContentRule.name can't be overwritten.");
  }

  get params(): string {
    return !this.raws.showArguments && this.contentArguments.nodes.length === 0
      ? ''
      : this.contentArguments.toString();
  }
  set params(value: string | number | undefined) {
    throw new Error("ContentRule.params can't be overwritten.");
  }

  constructor(defaults?: ContentRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ContentRule);
  constructor(defaults?: ContentRuleProps, inner?: sassInternal.ContentRule) {
    super(defaults as unknown as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.contentArguments = new ArgumentList(undefined, inner.arguments);
    }
    this._contentArguments ??= new ArgumentList();
  }

  clone(overrides?: Partial<ContentRuleProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'contentArguments']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['name', 'params', 'contentArguments'], inputs);
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<ArgumentList> {
    return [this.contentArguments];
  }
}

interceptIsClean(ContentRule);
