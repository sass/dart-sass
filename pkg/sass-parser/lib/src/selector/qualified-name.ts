// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Interpolation, InterpolationProps} from '../interpolation';
import {LazySource} from '../lazy-source';
import {AnyNode, Node, NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import {AnyStatement} from '../statement';
import * as utils from '../utils';

/**
 * The initializer properties for {@link QualifiedName} passed as an options
 * object.
 *
 * @category Selector
 */
export interface QualifiedNameObjectProps extends NodeProps {
  namespace?: Interpolation | InterpolationProps;
  name: Interpolation | InterpolationProps;
  raws?: QualifiedNameRaws;
}

/**
 * The initializer properties for {@link QualifiedName}.
 *
 * A single interpolation (which can be a plain string) is interpreted as a name
 * in the default namespace.
 *
 * @category Selector
 */
export type QualifiedNameProps =
  | QualifiedNameObjectProps
  | Interpolation
  | InterpolationProps;

/**
 * Raws indicating how to precisely serialize a {@link QualifiedName}.
 *
 * @category Selector
 */
// eslint-disable-next-line @typescript-eslint/no-empty-interface -- No raws for a selector expression yet.
export interface QualifiedNameRaws {}

/**
 * A [qualified name].
 *
 * [qualified name]: https://www.w3.org/TR/css3-namespace/#css-qnames
 *
 * @category Selector
 */
export class QualifiedName extends Node {
  readonly sassType = 'qualified-name' as const;
  declare raws: QualifiedNameRaws;

  /**
   * The qualified identifier's namespace.
   *
   * If this is `undefined`, this name belongs to the default namespace. If it's
   * the empty string, this name belongs to no namespace. If it's `*`, this name
   * belongs to any namespace. Otherwise, this belongs to the namespace with the
   * given name.
   */
  get namespace(): Interpolation | undefined {
    return this._namespace;
  }
  set namespace(value: Interpolation | InterpolationProps | undefined) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._namespace) this._namespace.parent = undefined;
    const namespace =
      value === undefined
        ? undefined
        : typeof value === 'object' && 'sassType' in value
          ? value
          : new Interpolation(value);
    if (namespace) namespace.parent = this;
    this._namespace = namespace;
  }
  private declare _namespace: Interpolation | undefined;

  /** The identifier name. */
  get name(): Interpolation {
    return this._name;
  }
  set name(value: Interpolation | InterpolationProps) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._name) this._name.parent = undefined;
    const name =
      value instanceof Interpolation ? value : new Interpolation(value);
    name.parent = this;
    this._name = name;
  }
  private declare _name: Interpolation;

  constructor(defaults?: QualifiedNameProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.QualifiedName);
  constructor(defaults?: object | string, inner?: sassInternal.QualifiedName) {
    if (!(typeof defaults === 'object' && 'name' in defaults)) {
      defaults = {name: defaults};
    }
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      if (inner.namespace)
        this.namespace = new Interpolation(undefined, inner.namespace);
      this.name = new Interpolation(undefined, inner.name);
    }
  }

  clone(overrides?: Partial<QualifiedNameObjectProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      {name: 'namespace', explicitUndefined: true},
      'name',
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['name', 'namespace'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.namespace === undefined
      ? this.name.toString()
      : `${this.namespace}|${this.name}`;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    const result: Array<Exclude<AnyNode, AnyStatement>> = [];
    if (this.namespace) result.push(this.namespace);
    result.push(this.name);
    return result;
  }
}
