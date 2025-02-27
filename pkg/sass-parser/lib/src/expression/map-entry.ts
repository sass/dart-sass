// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Expression, ExpressionProps} from './index';
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
  key: Expression | ExpressionProps;
  value: Expression | ExpressionProps;
}

/**
 * The initializer properties for {@link MapEntry}.
 *
 * @category Expression
 */
export type MapEntryProps =
  | MapEntryObjectProps
  | [Expression | ExpressionProps, Expression | ExpressionProps];

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
  get key(): Expression {
    return this._key!;
  }
  set key(key: Expression | ExpressionProps) {
    if (this._key) this._key.parent = undefined;
    if (!('sassType' in key)) key = fromProps(key);
    if (key) key.parent = this;
    this._key = key;
  }
  private declare _key?: Expression;

  /** The map value. */
  get value(): Expression {
    return this._value!;
  }
  set value(value: Expression | ExpressionProps) {
    if (this._value) this._value.parent = undefined;
    if (!('sassType' in value)) value = fromProps(value);
    if (value) value.parent = this;
    this._value = value;
  }
  private declare _value?: Expression;

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
  get nonStatementChildren(): ReadonlyArray<Expression> {
    return [this.key, this.value];
  }
}
