// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {StringExpression} from './expression/string';
import {ImportList} from './import-list';
import {LazySource} from './lazy-source';
import {AnyNode, Node, NodeProps} from './node';
import * as sassInternal from './sass-internal';
import {RawWithValue} from './raw-with-value';
import {AnyStatement} from './statement';
import * as utils from './utils';

/**
 * The set of raws supported by {@link DynamicImport}.
 *
 * @category Statement
 */
export interface DynamicImportRaws {
  /**
   * The whitespace before {@link DynamicImport.url}.
   */
  before?: string;

  /** The text of the string used to write {@link DynamicImport.url}. */
  url?: RawWithValue<string>;

  /**
   * The space symbols between the end of {@link DynamicImport.url} and the
   * comma afterwards. Always empty for a URL that doesn't have a trailing
   * comma.
   */
  after?: string;
}

/**
 * The properties for {@link DynamicImport} that are passed as an object.
 *
 * @category Statement
 */
export type DynamicImportObjectProps = NodeProps & {
  raws?: DynamicImportRaws;
  url: string;
};

/**
 * The initializer properties for {@link DynamicImport}.
 *
 * @category Statement
 */
export type DynamicImportProps = string | DynamicImportObjectProps;

/**
 * A single URL passed to an `@import` rule that's treated as a dynamic Sass
 * load rather than a plain-CSS `@import` rule. This is always included in an
 * {@link ImportRule}.
 *
 * @category Statement
 */
export class DynamicImport extends Node {
  readonly sassType = 'dynamic-import' as const;
  declare raws: DynamicImportRaws;
  declare parent: ImportList | undefined;

  /** The URL of the stylesheet to load. */
  declare url: string;

  constructor(defaults: DynamicImportProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.DynamicImport);
  constructor(
    defaults?: DynamicImportProps,
    inner?: sassInternal.DynamicImport,
  ) {
    if (typeof defaults === 'string') defaults = {url: defaults};
    super(defaults);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.url = inner.urlString;
    }
  }

  clone(overrides?: Partial<DynamicImportObjectProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'url']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['url'], inputs);
  }

  /** @hidden */
  toString(): string {
    return this.raws.url?.value === this.url
      ? this.raws.url.raw
      : new StringExpression({text: this.url, quotes: true}).toString();
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    return [];
  }
}
