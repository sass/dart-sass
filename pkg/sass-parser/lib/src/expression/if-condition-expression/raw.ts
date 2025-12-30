// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {NodeProps} from '../../node';
import type * as sassInternal from '../../sass-internal';
import * as utils from '../../utils';
import {AnyIfConditionExpression, IfConditionExpression} from './index';
import {IfEntry} from '../if-entry';
import {LazySource} from '../../lazy-source';
import {Interpolation, InterpolationProps} from '../../interpolation';

/**
 * The set of raws supported by {@link IfConditionRaw}.
 *
 * @category Expression
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a raw condition yet.
export interface IfConditionRawRaws {}

/**
 * The initializer properties for {@link IfConditionRaw}.
 *
 * @category Expression
 */
export interface IfConditionRawProps extends NodeProps {
  raws?: IfConditionRawRaws;
  rawInterpolation: Interpolation | InterpolationProps;
}

/**
 * A raw interpolated condition in an `if()` condition that couldn't be parsed
 * as anything more specific.
 *
 * For example, this is produced by `media(...) var(--and) supports(...)`.
 *
 * @category Expression
 */
export class IfConditionRaw extends IfConditionExpression {
  readonly sassType = 'if-condition-raw' as const;
  declare raws: IfConditionRawRaws;
  declare parent: IfEntry | AnyIfConditionExpression | undefined;

  /** The rawInterpolation contents of the condition. */
  get rawInterpolation(): Interpolation {
    return this._rawInterpolation!;
  }
  set rawInterpolation(rawInterpolation: Interpolation | InterpolationProps) {
    if (this._rawInterpolation) this._rawInterpolation.parent = undefined;
    const built =
      typeof rawInterpolation === 'object' && 'sassType' in rawInterpolation
        ? rawInterpolation
        : new Interpolation(rawInterpolation);
    built.parent = this;
    this._rawInterpolation = built;
  }
  private declare _rawInterpolation?: Interpolation;

  constructor(defaults: IfConditionRawProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.IfConditionRaw);
  constructor(defaults?: object, inner?: sassInternal.IfConditionRaw) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.rawInterpolation = new Interpolation(undefined, inner.text);
    }
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfConditionRawProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'rawInterpolation']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['rawInterpolation'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.rawInterpolation.toString();
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    return [this.rawInterpolation];
  }
}
