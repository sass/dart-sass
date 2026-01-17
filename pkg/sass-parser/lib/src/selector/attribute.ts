// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import type {AnyNode, NodeProps} from '../node';
import type {AnyStatement} from '../statement';
import {Interpolation, InterpolationProps} from '../interpolation';
import {LazySource} from '../lazy-source';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {QualifiedName, QualifiedNameProps} from './qualified-name';
import {SimpleSelector} from './index';

/**
 * An operator that defines the meaning of a {@link AttributeSelector}.
 *
 * @category Selector
 */
export type AttributeSelectorOperator = '=' | '~=' | '|=' | '^=' | '$=' | '*=';

/**
 * The initializer properties for {@link AttributeSelector}.
 *
 * @category Selector
 */
export interface AttributeSelectorProps extends NodeProps {
  attribute: QualifiedName | QualifiedNameProps;
  operator?: AttributeSelectorOperator;
  value?: Interpolation | InterpolationProps;
  modifier?: Interpolation | InterpolationProps;
  raws?: AttributeSelectorRaws;
}

/**
 * Raws indicating how to precisely serialize an {@AttributeSelector}.
 *
 * @category Selector
 */
export interface AttributeSelectorRaws {
  /** The whitespace between the opening bracket and the attribute name. */
  afterOpen?: string;

  /**
   * The whitespace between the final component of the selector and the closing
   * bracket.
   */
  beforeClose?: string;

  /** The whitespace before the operator. */
  beforeOperator?: string;

  /** The whitespace after the operator. */
  afterOperator?: string;

  /**
   * The whitespace after the value.
   *
   * This is only set automatically when the selector has a modifier.
   */
  afterValue?: string;
}

/**
 * An attribute selector.
 *
 * This selects for elements with the given attribute, and optionally with a
 * value matching certain conditions as well.
 *
 * @category Selector
 */
export class AttributeSelector extends SimpleSelector {
  readonly sassType = 'attribute' as const;
  declare raws: AttributeSelectorRaws;

  /** The name of the attribute being selected for. */
  get attribute(): QualifiedName {
    return this._attribute;
  }
  set attribute(attribute: QualifiedName | QualifiedNameProps) {
    if (this._attribute) this._attribute.parent = undefined;
    const built =
      typeof attribute === 'object' &&
      'sassType' in attribute &&
      attribute.sassType === 'qualified-name'
        ? attribute
        : new QualifiedName(attribute);
    built.parent = this;
    this._attribute = built;
  }
  declare private _attribute: QualifiedName;

  /**
   * The operator that defines the semantics of {@link value}.
   *
   * If this is `undefined`, this matches any element with the given property,
   * regardless of this value. It's ignored if {@link value} is `undefined`.
   */
  get operator(): AttributeSelectorOperator | undefined {
    return this._operator;
  }
  set operator(operator: AttributeSelectorOperator | undefined) {
    this._operator = operator;
  }
  declare private _operator: AttributeSelectorOperator | undefined;

  /**
   * An assertion about the value of {@link attribute}.
   *
   * The precise semantics of this string are defined by {@link operator}.
   *
   * This may be a quoted or unquoted string. If it's quoted, the quotes and any
   * escape sequences are included as part of the value's text.
   *
   * If this is `undefined`, this matches any element with the given property,
   * regardless of this value. It's ignored if {@link operator} is `undefined`.
   */
  get value(): Interpolation | undefined {
    return this._value;
  }
  set value(value: Interpolation | InterpolationProps | undefined) {
    if (this._value) this._value.parent = undefined;
    const built = value
      ? typeof value === 'object' && 'sassType' in value
        ? value
        : new Interpolation(value)
      : undefined;
    if (built) built.parent = this;
    this._value = built;
  }
  declare private _value: Interpolation | undefined;

  /**
   * The modifier which indicates how the attribute selector should be
   * processed.
   *
   * See for example [case-sensitivity] modifiers.
   *
   * [case-sensitivity]: https://www.w3.org/TR/selectors-4/#attribute-case
   *
   * This is ignored if {@link operator} or {@link this.value} is `undefined`.
   */
  get modifier(): Interpolation | undefined {
    return this._modifier;
  }
  set modifier(modifier: Interpolation | InterpolationProps | undefined) {
    if (this._modifier) this._modifier.parent = undefined;
    const built = modifier
      ? typeof modifier === 'object' && 'sassType' in modifier
        ? modifier
        : new Interpolation(modifier)
      : undefined;
    if (built) built.parent = this;
    this._modifier = built;
  }
  declare private _modifier: Interpolation | undefined;

  constructor(defaults: AttributeSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.AttributeSelector);
  constructor(defaults?: object, inner?: sassInternal.AttributeSelector) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.attribute = new QualifiedName(undefined, inner.name);
      this.operator = inner.op?.toString() as
        | AttributeSelectorOperator
        | undefined;
      if (inner.value) this.value = new Interpolation(undefined, inner.value);
      if (inner.modifier) {
        this.modifier = new Interpolation(undefined, inner.modifier);
      }
    }
  }

  clone(overrides?: Partial<AttributeSelectorProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'attribute',
      {name: 'operator', explicitUndefined: true},
      {name: 'value', explicitUndefined: true},
      {name: 'modifier', explicitUndefined: true},
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['attribute', 'operator', 'value', 'modifier'],
      inputs,
    );
  }

  /** @hidden */
  toString(): string {
    let result = `[${this.raws.afterOpen ?? ''}${this.attribute}`;
    if (this.operator && this.value) {
      result +=
        (this.raws.beforeOperator ?? '') +
        this.operator +
        (this.raws.afterOperator ?? '') +
        this.value;
      if (this.modifier) {
        result += (this.raws.afterValue ?? ' ') + this.modifier;
      } else {
        result += this.raws.afterValue ?? '';
      }
    }
    result += `${this.raws.beforeClose ?? ''}]`;
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    const result: Array<Exclude<AnyNode, AnyStatement>> = [this.attribute];
    if (this.value) result.push(this.value);
    if (this.modifier) result.push(this.modifier);
    return result;
  }
}
