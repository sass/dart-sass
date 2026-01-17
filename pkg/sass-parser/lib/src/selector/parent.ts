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
 * The initializer properties for {@link ParentSelector}.
 *
 * @category Selector
 */
export interface ParentSelectorProps extends NodeProps {
  // We can't make this optional because that would allow an empty object to be
  // a valid simple selector property set.
  suffix: Interpolation | InterpolationProps | undefined;
  raws?: ParentSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize a {@ParentSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a parent selector yet.
export interface ParentSelectorRaws {}

/**
 * A parent selector.
 *
 * This selects elements matching the selector beneath which it's nested.
 *
 * @category Selector
 */
export class ParentSelector extends SimpleSelector {
  readonly sassType = 'parent' as const;
  declare raws: ParentSelectorRaws;

  /**
   * The suffix that will be added to the parent selector after it's been
   * resolved.
   *
   * This is assumed to be a valid identifier suffix. It may be `null`,
   * indicating that the parent selector will not be modified.
   */
  get suffix(): Interpolation | undefined {
    return this._suffix;
  }
  set suffix(suffix: Interpolation | InterpolationProps | undefined) {
    if (this._suffix) this._suffix.parent = undefined;
    const built =
      suffix === undefined
        ? undefined
        : typeof suffix === 'object' && 'sassType' in suffix
          ? suffix
          : new Interpolation(suffix);
    if (built) built.parent = this;
    this._suffix = built;
  }
  declare private _suffix: Interpolation | undefined;

  constructor(defaults?: ParentSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ParentSelector);
  constructor(defaults?: object, inner?: sassInternal.ParentSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      if (inner.suffix) {
        this.suffix = new Interpolation(undefined, inner.suffix);
      }
    }
  }

  clone(overrides?: Partial<ParentSelectorProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'suffix', explicitUndefined: true},
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['suffix'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.suffix ? `&${this.suffix}` : '&';
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return this.suffix ? [this.suffix] : [];
  }
}
