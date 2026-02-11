// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {AnyExpression, ExpressionProps} from './index';
import {fromProps} from './from-props';
import {Node, NodeProps} from '../node';
import {MapExpression} from './map';
import * as utils from '../utils';

/**
 * The set of raws supported by {@link MapEntry}.
 *
 * @category Expression
 */
export interface MapEntryRaws {
  /** The whitespace before the key. */
  before?: string;

  /** The whitespace and colon between the key and its value. */
  between?: string;

  /**
   * The space symbols between the end value and the comma afterwards. Always
   * empty for an entry that doesn't have a trailing comma.
   */
  after?: string;
}

/**
 * The initializer properties for {@link MapEntry} passed as an
 * options object.
 *
 * @category Expression
 */
export interface MapEntryObjectProps extends NodeProps {
  raws?: MapEntryRaws;
  key: AnyExpression | ExpressionProps;
  value: AnyExpression | ExpressionProps;
}

/**
 * The initializer properties for {@link MapEntry}.
 *
 * @category Expression
 */
export type MapEntryProps =
  | MapEntryObjectProps
  | [AnyExpression | ExpressionProps, AnyExpression | ExpressionProps];

/**
 * A single key/value pair in a map literal. This is always included in a {@link
 * Map}.
 *
 * @category Expression
 */
export class MapEntry extends Node {
  readonly sassType = 'map-entry' as const;
  declare raws: MapEntryRaws;
  declare parent: MapExpression | undefined;

  /** The map key. */
  get key(): AnyExpression {
    return this._key!;
  }
  set key(key: AnyExpression | ExpressionProps) {
    if (this._key) this._key.parent = undefined;
    const built = 'sassType' in key ? key : fromProps(key);
    built.parent = this;
    this._key = built;
  }
  declare private _key?: AnyExpression;

  /** The map value. */
  get value(): AnyExpression {
    return this._value!;
  }
  set value(value: AnyExpression | ExpressionProps) {
    if (this._value) this._value.parent = undefined;
    const built = 'sassType' in value ? value : fromProps(value);
    built.parent = this;
    this._value = built;
  }
  declare private _value?: AnyExpression;

  constructor(defaults: MapEntryProps) {
    if (Array.isArray(defaults)) {
      defaults = {key: defaults[0], value: defaults[1]};
    }
    super(defaults);
    this.raws ??= {};
  }

  clone(overrides?: Partial<MapEntryObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'key', 'value']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['key', 'value'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.key + (this.raws.between ?? ': ') + this.value;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<AnyExpression> {
    return [this.key, this.value];
  }
}
