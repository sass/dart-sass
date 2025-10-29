// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from '../lazy-source';
import type {AnyNode, NodeProps} from '../node';
import type {AnyStatement} from '../statement';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {QualifiedName, QualifiedNameProps} from './qualified-name';
import {SimpleSelector} from './index';

/**
 * The initializer properties for {@link TypeSelector}.
 *
 * @category Selector
 */
export interface TypeSelectorProps extends NodeProps {
  type: QualifiedName | QualifiedNameProps;
  raws?: TypeSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize an {@TypeSelector}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a type selector yet.
export interface TypeSelectorRaws {}

/**
 * A type selector.
 *
 * This selects elements of the given type.
 *
 * @category Selector
 */
export class TypeSelector extends SimpleSelector {
  readonly sassType = 'type' as const;
  declare raws: TypeSelectorRaws;

  /** The class name that this selects. */
  get type(): QualifiedName {
    return this._type;
  }
  set type(type: QualifiedName | QualifiedNameProps) {
    if (this._type) this._type.parent = undefined;
    const built =
      typeof type === 'object' &&
      'sassType' in type &&
      type.sassType === 'qualified-name'
        ? type
        : new QualifiedName(type);
    built.parent = this;
    this._type = built;
  }
  private declare _type: QualifiedName;

  constructor(defaults: TypeSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.TypeSelector);
  constructor(defaults?: object, inner?: sassInternal.TypeSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.type = new QualifiedName(undefined, inner.name);
    }
  }

  clone(overrides?: Partial<TypeSelectorProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'type']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['type'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.type.toString();
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [this.type];
  }
}
