// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {ImportList} from './import-list';
import {Interpolation, InterpolationProps} from './interpolation';
import {LazySource} from './lazy-source';
import {Node, NodeProps} from './node';
import * as sassInternal from './sass-internal';
import * as utils from './utils';

/**
 * The set of raws supported by {@link StaticImport}.
 *
 * @category Statement
 */
export interface StaticImportRaws {
  /**
   * The whitespace before {@link StaticImport.staticUrl}.
   */
  before?: string;

  /**
   * The whitespace between {@link StaticImport.staticUrl} and {@link
   * StaticImport.modifiers}. Always empty if `modifiers` is undefined.
   */
  between?: string;

  /**
   * The space symbols between {@link StaticImport.modifiers} (if it's defined)
   * or {@link StaticImport.staticUrl} (otherwise) URL and the comma afterwards.
   * Always empty for a URL that doesn't have a trailing comma.
   */
  after?: string;
}

/**
 * The initializer properties for {@link StaticImport}.
 *
 * @category Statement
 */
export type StaticImportProps = NodeProps & {
  raws?: StaticImportRaws;
  staticUrl: InterpolationProps;
  modifiers?: InterpolationProps;
};

/**
 * A single URL passed to an `@import` rule that's treated as a plain-CSS
 * `@import` rather than a dynamic Sass load. This is always included in an
 * {@link ImportRule}.
 *
 * @category Statement
 */
export class StaticImport extends Node {
  readonly sassType = 'static-import' as const;
  declare raws: StaticImportRaws;
  declare parent: ImportList | undefined;

  /** The URL of the imported stylesheet. */
  get staticUrl(): Interpolation {
    return this._staticUrl!;
  }
  set staticUrl(value: Interpolation | InterpolationProps) {
    if (this._staticUrl) this._staticUrl.parent = undefined;
    const staticUrl =
      value instanceof Interpolation ? value : new Interpolation(value);
    staticUrl.parent = this;
    this._staticUrl = staticUrl;
  }
  declare private _staticUrl?: Interpolation;

  /**
   * The additional modifiers, like media queries and `supports()`, attached to
   * this import.
   */
  get modifiers(): Interpolation | undefined {
    return this._modifiers!;
  }
  set modifiers(value: Interpolation | InterpolationProps | undefined) {
    if (this._modifiers) this._modifiers.parent = undefined;
    if (value) {
      const modifiers =
        value instanceof Interpolation ? value : new Interpolation(value);
      modifiers.parent = this;
      this._modifiers = modifiers;
    } else {
      this._modifiers = undefined;
    }
  }
  declare private _modifiers?: Interpolation;

  constructor(defaults: string | StaticImportProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.StaticImport);
  constructor(
    defaults?: string | StaticImportProps,
    inner?: sassInternal.StaticImport,
  ) {
    if (typeof defaults === 'string') defaults = {staticUrl: defaults};
    super(defaults);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.staticUrl = new Interpolation(undefined, inner.url);
      if (inner.modifiers) {
        this.modifiers = new Interpolation(undefined, inner.modifiers);
      }
    }
  }

  clone(overrides?: Partial<StaticImportProps>): this {
    return utils.cloneNode(this, overrides, [
      'raws',
      'staticUrl',
      {name: 'modifiers', explicitUndefined: true},
    ]);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['staticUrl', 'modifiers'], inputs);
  }

  /** @hidden */
  toString(): string {
    // TODO: If staticUrl is of the form `url("...")`, it gets parsed as an
    // interpolation around a `url()` function, which isn't actually valid as
    // source in this position. Normalize that here.
    return (
      this.staticUrl +
      (this.modifiers ? (this.raws.between ?? ' ') + this.modifiers : '')
    );
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    const result = [this.staticUrl];
    if (this.modifiers) result.push(this.modifiers);
    return result;
  }
}
