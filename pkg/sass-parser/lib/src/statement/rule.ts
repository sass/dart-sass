// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {RuleRaws as PostcssRuleRaws} from 'postcss/lib/rule';

import {Interpolation} from '../interpolation';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
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
    | {selectorInterpolation: Interpolation | string}
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
    return this.selectorInterpolation.toString();
  }
  set selector(value: string) {
    this.selectorInterpolation = value;
  }

  /** The interpolation that represents this rule's selector. */
  get selectorInterpolation(): Interpolation {
    return this._selectorInterpolation!;
  }
  set selectorInterpolation(selectorInterpolation: Interpolation | string) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._selectorInterpolation) {
      this._selectorInterpolation.parent = undefined;
    }
    if (typeof selectorInterpolation === 'string') {
      selectorInterpolation = new Interpolation({
        nodes: [selectorInterpolation],
      });
    }
    selectorInterpolation.parent = this;
    this._selectorInterpolation = selectorInterpolation;
  }
  private _selectorInterpolation?: Interpolation;

  constructor(defaults: RuleProps);
  constructor(_: undefined, inner: sassInternal.StyleRule);
  /** @hidden */
  constructor(defaults?: RuleProps, inner?: sassInternal.StyleRule) {
    // PostCSS claims that it requires either selector or selectors, but we
    // define the former as a getter instead.
    super(defaults as postcss.RuleProps);
    if (inner) {
      this.source = new LazySource(inner);
      this.selectorInterpolation = new Interpolation(undefined, inner.selector);
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
      ['nodes', 'raws', 'selectorInterpolation'],
      ['selector', 'selectors']
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['selector', 'selectorInterpolation', 'nodes'],
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
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    return [this.selectorInterpolation];
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(Rule);
