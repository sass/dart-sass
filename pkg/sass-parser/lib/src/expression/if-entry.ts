// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {AnyExpression, ExpressionProps} from './index';
import {fromProps} from './from-props';
import {Node, NodeProps} from '../node';
import * as utils from '../utils';
import {
  AnyIfConditionExpression,
  IfConditionExpressionProps,
} from './if-condition-expression';
import {fromProps as ifConditionExpressionFromProps} from './if-condition-expression/from-props';
import {IfExpression} from './if';

/**
 * The set of raws supported by {@link IfEntry}.
 *
 * @category Expression
 */
export interface IfEntryRaws {
  /**
   * The exact formatting of the `else` keyword. This is only set if this entry
   * uses `else` in place of a condition.
   */
  else?: string;

  /** The whitespace before the condition. */
  before?: string;

  /** The whitespace and colon between the condition and its value. */
  between?: string;

  /**
   * The space symbols between the end value and the semicolon afterwards. Always
   * empty for an entry that doesn't have a trailing semicolon.
   */
  after?: string;
}

/**
 * The initializer properties for {@link IfEntry} passed as an
 * options object.
 *
 * @category Expression
 */
export interface IfEntryObjectProps extends NodeProps {
  raws?: IfEntryRaws;
  condition: AnyIfConditionExpression | IfConditionExpressionProps | 'else';
  value: AnyExpression | ExpressionProps;
}

/**
 * The initializer properties for {@link IfEntry}.
 *
 * @category Expression
 */
export type IfEntryProps =
  | IfEntryObjectProps
  | [
      AnyIfConditionExpression | IfConditionExpressionProps | 'else',
      AnyExpression | ExpressionProps,
    ];

/**
 * A single condition/value pair in an {@link IfExpression}.
 *
k * @category Expression
 */
export class IfEntry extends Node {
  readonly sassType = 'if-entry' as const;
  declare raws: IfEntryRaws;
  declare parent: IfExpression | undefined;

  /** The entry's condition. */
  get condition(): AnyIfConditionExpression | 'else' {
    return this._condition!;
  }
  set condition(
    condition: AnyIfConditionExpression | IfConditionExpressionProps | 'else',
  ) {
    if (typeof this._condition === 'object') this._condition.parent = undefined;
    if (typeof condition === 'object') {
      const built = ifConditionExpressionFromProps(condition);
      built.parent = this;
      this._condition = built;
    } else {
      this._condition = condition;
    }
  }
  declare private _condition?: AnyIfConditionExpression | 'else';

  /** The entry's value. */
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

  constructor(defaults: IfEntryProps) {
    if (Array.isArray(defaults)) {
      defaults = {condition: defaults[0], value: defaults[1]};
    }
    super(defaults);
    this.raws ??= {};
  }

  clone(overrides?: Partial<IfEntryObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'condition', 'value']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['condition', 'value'], inputs);
  }

  /** @hidden */
  toString(): string {
    return (
      (this.condition === 'else'
        ? (this.raws.else ?? 'else')
        : this.condition) +
      (this.raws.between ?? ': ') +
      this.value
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<
    AnyExpression | AnyIfConditionExpression
  > {
    const children = [];
    if (typeof this.condition === 'object') children.push(this.condition);
    children.push(this.value);
    return children;
  }
}
