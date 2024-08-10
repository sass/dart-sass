// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {RootRaws} from 'postcss/lib/root';

import * as sassParser from '../..';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {
  ChildNode,
  ContainerProps,
  NewNode,
  Statement,
  appendInternalChildren,
  normalize,
} from '.';
import {_Root} from './root-internal';

export type {RootRaws} from 'postcss/lib/root';

/**
 * The initializer properties for {@link Root}.
 *
 * @category Statement
 */
export interface RootProps extends ContainerProps {
  raws?: RootRaws;
}

/**
 * The root node of a Sass stylesheet. Extends [`postcss.Root`].
 *
 * [`postcss.Root`]: https://postcss.org/api/#root
 *
 * @category Statement
 */
export class Root extends _Root implements Statement {
  readonly sassType = 'root' as const;
  declare parent: undefined;
  declare raws: RootRaws;

  /** @hidden */
  readonly nonStatementChildren = [] as const;

  constructor(defaults?: RootProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.Stylesheet);
  constructor(defaults?: object, inner?: sassInternal.Stylesheet) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<RootProps>): this {
    return utils.cloneNode(this, overrides, ['nodes', 'raws']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['nodes'], inputs);
  }

  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}
