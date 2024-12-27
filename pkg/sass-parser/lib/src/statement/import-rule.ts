// Copyright 2024 Google Inc. Import of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {AtRuleRaws} from 'postcss/lib/at-rule';

import {ImportList, ImportListProps} from '../import-list';
import {LazySource} from '../lazy-source';
import {NodeProps} from '../node';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Statement, StatementWithChildren} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link ImportRule}.
 *
 * @category Statement
 */
export type ImportRuleRaws = Omit<AtRuleRaws, 'params'>;

/**
 * The initializer properties for {@link ImportRule}.
 *
 * @category Statement
 */
export interface ImportRuleProps extends NodeProps {
  raws?: ImportRuleRaws;
  imports: ImportListProps;
}

/**
 * A `@import` rule. Extends [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class ImportRule
  extends _AtRule<Partial<ImportRuleProps>>
  implements Statement
{
  readonly sassType = 'import-rule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: ImportRuleRaws;
  declare readonly nodes: undefined;

  /** The imports loaded by this rule. */
  get imports(): ImportList {
    return this._imports!;
  }
  set imports(imports: ImportList | ImportListProps) {
    if (this._imports) {
      this._imports.parent = undefined;
    }
    this._imports =
      imports instanceof ImportList ? imports : new ImportList(imports);
    this._imports.parent = this;
  }
  private declare _imports: ImportList;

  get name(): string {
    return 'import';
  }
  set name(value: string) {
    throw new Error("ImportRule.name can't be overwritten.");
  }

  get params(): string {
    return this.imports.toString();
  }
  set params(value: string | number | undefined) {
    throw new Error("ImportRule.params can't be overwritten.");
  }

  /**
   * Iterators that are currently active within this rule's {@link imports}.
   * Their indices refer to the last position that has already been sent to the
   * callback, and are updated when {@link _imports} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults: ImportRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.ImportRule);
  constructor(defaults?: ImportRuleProps, inner?: sassInternal.ImportRule) {
    super(defaults as unknown as postcss.AtRuleProps);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.imports = new ImportList(undefined, inner);
    }
  }

  clone(overrides?: Partial<ImportRuleProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'imports']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['imports'], inputs);
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<ImportList> {
    return [this.imports];
  }
}

interceptIsClean(ImportRule);
