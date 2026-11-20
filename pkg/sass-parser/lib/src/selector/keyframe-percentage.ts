// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import type {NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {SimpleSelector} from '.';

/**
 * The initializer properties for {@link KeyframePercentage}.
 *
 * @category Selector
 */
export interface KeyframePercentageProps extends NodeProps {
  percentage: string;
}

/**
 * A percentage selecting a step in a `@keyframes` rule.
 *
 * @category Selector
 */
export class KeyframePercentage extends SimpleSelector {
  readonly sassType = 'keyframe-percentage' as const;

  /** The percentage including the percent sign, for example `12.5%`. */
  declare percentage: string;

  constructor(defaults: KeyframePercentageProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.KeyframePercentage);
  constructor(
    defaults?: KeyframePercentageProps,
    inner?: sassInternal.KeyframePercentage,
  ) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.percentage = inner.percentage;
    }
  }

  clone(overrides?: Partial<KeyframePercentageProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'percentage']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['percentage'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.percentage;
  }

  /** @hidden */
  get nonStatementChildren(): readonly [] {
    return [];
  }
}
