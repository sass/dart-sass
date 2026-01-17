// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import {AnyNode, Node, NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import {AnyStatement} from '../statement';
import * as utils from '../utils';
import {SelectorCombinator} from './complex';
import {CompoundSelector, CompoundSelectorProps} from './compound';

/**
 * The initializer properties for {@link ComplexSelectorComponent} passed as an
 * options object..
 *
 * @category Selector
 */
export interface ComplexSelectorComponentObjectProps extends NodeProps {
  compound: CompoundSelector | CompoundSelectorProps;
  combinator?: SelectorCombinator;
  raws?: ComplexSelectorComponentRaws;
}

/**
 * The initializer properties for {@link ComplexSelectorComponents}.
 *
 * @category Selector
 */
export type ComplexSelectorComponentProps =
  | ComplexSelectorComponentObjectProps
  | CompoundSelector
  | CompoundSelectorProps;

/**
 * Raws indicating how to precisely serialize a {@ComplexSelectorComponent}.
 *
 * @category Selector
 */
export interface ComplexSelectorComponentRaws {
  /**
   * The whitespace between the combinator and the compound selector.
   *
   * This is ignored unless {@link ComplexSelectorComponent.combinator} is
   * defined.
   */
  between?: string;
}

/**
 * A single component of a {@link ComplexSelector}, which is a compound selector
 * that may or may not have a combinator before it.
 *
 * @category Selector
 */
export class ComplexSelectorComponent extends Node {
  readonly sassType = 'complex-selector-component' as const;
  declare raws: ComplexSelectorComponentRaws;

  /**
   * The combinator after this component's compound selector.
   *
   * If this is undefined, it indicates that the component uses a descendent
   * combinator, or no combinator at all if it's at the beginning of the complex
   * selector.
   */
  get combinator(): SelectorCombinator | undefined {
    return this._combinator;
  }
  set combinator(combinator: SelectorCombinator | undefined) {
    this._combinator = combinator;
  }
  declare private _combinator: SelectorCombinator | undefined;

  /** This componnet's compound selector. */
  get compound(): CompoundSelector {
    return this._compound;
  }
  set compound(compound: CompoundSelector | CompoundSelectorProps) {
    if (this._compound) this._compound.parent = undefined;
    const built =
      'sassType' in compound && compound.sassType === 'compound-selector'
        ? compound
        : new CompoundSelector(compound);
    built.parent = this;
    this._compound = built;
  }
  declare private _compound: CompoundSelector;

  constructor(defaults: ComplexSelectorComponentProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ComplexSelectorComponent);
  constructor(
    defaults?: object,
    inner?: sassInternal.ComplexSelectorComponent,
  ) {
    if (defaults && !('compound' in defaults)) defaults = {compound: defaults};
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.compound = new CompoundSelector(undefined, inner.selector);
      // Multiple combinators will be removed soon so we don't bother
      // supporting it here.
      this.combinator = inner.combinator?.toString() as SelectorCombinator;
    }
  }

  clone(overrides?: Partial<ComplexSelectorComponentObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'compound',
      {name: 'combinator', explicitUndefined: true},
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['compound', 'combinator'], inputs);
  }

  /** @hidden */
  toString(): string {
    let result = this.compound.toString();
    if (this.combinator) {
      result += (this.raws.between ?? ' ') + this.combinator;
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [this.compound];
  }
}
