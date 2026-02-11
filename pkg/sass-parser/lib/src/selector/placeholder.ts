// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Interpolation, InterpolationProps} from '../interpolation';
import {LazySource} from '../lazy-source';
import type {AnyNode, NodeProps} from '../node';
import type {AnyStatement} from '../statement';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {SimpleSelector} from './index';

/**
 * The initializer properties for {@link PlaceholderSelector}.
 *
 * @category Selector
 */
export interface PlaceholderSelectorProps extends NodeProps {
  placeholder: Interpolation | InterpolationProps;
  raws?: PlaceholderSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize a {@PlaceholderSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a placeholder selector yet.
export interface PlaceholderSelectorRaws {}

/**
 * A placeholder selector.
 *
 * This selects no elements, and is only used as the target for `@extend` rules.
 *
 * @category Selector
 */
export class PlaceholderSelector extends SimpleSelector {
  readonly sassType = 'placeholder' as const;
  declare raws: PlaceholderSelectorRaws;

  /** The placeholder name that this selects. */
  get placeholder(): Interpolation {
    return this._placeholder;
  }
  set placeholder(placeholder: Interpolation | InterpolationProps) {
    if (this._placeholder) this._placeholder.parent = undefined;
    const built =
      typeof placeholder === 'object' && 'sassType' in placeholder
        ? placeholder
        : new Interpolation(placeholder);
    built.parent = this;
    this._placeholder = built;
  }
  declare private _placeholder: Interpolation;

  constructor(defaults: PlaceholderSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.PlaceholderSelector);
  constructor(defaults?: object, inner?: sassInternal.PlaceholderSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.placeholder = new Interpolation(undefined, inner.name);
    }
  }

  clone(overrides?: Partial<PlaceholderSelectorProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'placeholder']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['placeholder'], inputs);
  }

  /** @hidden */
  toString(): string {
    return `%${this.placeholder}`;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [this.placeholder];
  }
}
