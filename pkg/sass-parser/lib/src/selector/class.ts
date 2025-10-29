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
 * The initializer properties for {@link ClassSelector}.
 *
 * @category Selector
 */
export interface ClassSelectorProps extends NodeProps {
  class: Interpolation | InterpolationProps;
  raws?: ClassSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize an {@ClassSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a class selector yet.
export interface ClassSelectorRaws {}

/**
 * A class selector.
 *
 * This selects elements whose `class` attribute contains an identifier with the
 * given name.
 *
 * @category Selector
 */
export class ClassSelector extends SimpleSelector {
  readonly sassType = 'class' as const;
  declare raws: ClassSelectorRaws;

  /** The class name that this selects. */
  get class(): Interpolation {
    return this._class;
  }
  set class(className: Interpolation | InterpolationProps) {
    if (this._class) this._class.parent = undefined;
    const built =
      typeof className === 'object' && 'sassType' in className
        ? className
        : new Interpolation(className);
    built.parent = this;
    this._class = built;
  }
  private declare _class: Interpolation;

  constructor(defaults: ClassSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ClassSelector);
  constructor(defaults?: object, inner?: sassInternal.ClassSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.class = new Interpolation(undefined, inner.name);
    }
  }

  clone(overrides?: Partial<ClassSelectorProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'class']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['class'], inputs);
  }

  /** @hidden */
  toString(): string {
    return `.${this.class}`;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [this.class];
  }
}
