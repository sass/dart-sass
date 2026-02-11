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
import {SimpleSelector} from '.';

/**
 * The initializer properties for {@link UniversalSelector}.
 *
 * @category Selector
 */
export interface UniversalSelectorProps extends NodeProps {
  // We can't make this optional because that would allow an empty object to be
  // a valid simple selector property set.
  namespace: Interpolation | InterpolationProps | undefined;
  raws?: UniversalSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize an {@UniversalSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a universal selector yet.
export interface UniversalSelectorRaws {}

/**
 * A type selector.
 *
 * This selects elements of the given type.
 *
 * @category Selector
 */
export class UniversalSelector extends SimpleSelector {
  readonly sassType = 'universal' as const;
  declare raws: UniversalSelectorRaws;

  /** The class name that this selects. */
  get namespace(): Interpolation | undefined {
    return this._namespace;
  }
  set namespace(namespace: Interpolation | InterpolationProps | undefined) {
    if (this._namespace) this._namespace.parent = undefined;
    const built =
      namespace === undefined
        ? undefined
        : typeof namespace === 'object' && 'sassType' in namespace
          ? namespace
          : new Interpolation(namespace);
    if (built) built.parent = this;
    this._namespace = built;
  }
  declare private _namespace: Interpolation | undefined;

  constructor(defaults?: UniversalSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.UniversalSelector);
  constructor(defaults?: object, inner?: sassInternal.UniversalSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      if (inner.namespace)
        this.namespace = new Interpolation(undefined, inner.namespace);
    }
  }

  clone(overrides?: Partial<UniversalSelectorProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'namespace', explicitUndefined: true},
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['namespace'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.namespace ? `${this.namespace}|*` : '*';
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return this.namespace ? [this.namespace] : [];
  }
}
