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
 * The initializer properties for {@link IDSelector}.
 *
 * @category Selector
 */
export interface IDSelectorProps extends NodeProps {
  id: Interpolation | InterpolationProps;
  raws?: IDSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize an {@IDSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for an ID selector yet.
export interface IDSelectorRaws {}

/**
 * An ID selector.
 *
 * This selects elements whose `id` attribute contains an identifier with the
 * given name.
 *
 * @category Selector
 */
export class IDSelector extends SimpleSelector {
  readonly sassType = 'id' as const;
  declare raws: IDSelectorRaws;

  /** The ID name that this selects. */
  get id(): Interpolation {
    return this._id;
  }
  set id(id: Interpolation | InterpolationProps) {
    if (this._id) this._id.parent = undefined;
    const built =
      typeof id === 'object' && 'sassType' in id ? id : new Interpolation(id);
    built.parent = this;
    this._id = built;
  }
  private declare _id: Interpolation;

  constructor(defaults: IDSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IDSelector);
  constructor(defaults?: object, inner?: sassInternal.IDSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.id = new Interpolation(undefined, inner.name);
    }
  }

  clone(overrides?: Partial<IDSelectorProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'id']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['id'], inputs);
  }

  /** @hidden */
  toString(): string {
    return `#${this.id}`;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [this.id];
  }
}
