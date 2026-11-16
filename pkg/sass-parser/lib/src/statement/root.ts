// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {RootRaws} from 'postcss/lib/root';

import * as sassParser from '../..';
import {LazyRaws} from '../lazy-raws';
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

class LazyRootRaws extends LazyRaws<sassInternal.Stylesheet> {
  declare after?: string;
  declare semicolon?: boolean;

  constructor(inner: sassInternal.Stylesheet) {
    super(inner, ['after', 'semicolon']);
  }

  protected _computeRaws(): void {
    const lastChild = this._node.children.at(-1);
    if (!lastChild) {
      this._setRawDefault('semicolon', () => undefined);
      this._setRawDefault('after', () => this._node.span.text);
      return;
    }

    const trailingSpan = this._node.span.after(lastChild.span);
    const textAfterSemicolon = this.#textAfterSemicolon(trailingSpan);
    if (textAfterSemicolon === null) {
      this._setRawDefault('semicolon', () => false);
      this._setRawDefault('after', () =>
        lastChild.hasChildren ? trailingSpan.text : '',
      );
    } else {
      this._setRawDefault('semicolon', () => !lastChild.hasChildren);
      this._setRawDefault('after', () => textAfterSemicolon);
    }
  }

  /**
   * Returns the text after {@link span}'s first semicolon, or `null` if it
   * doesn't contain a semicolon at all.
   */
  #textAfterSemicolon(span: sassInternal.FileSpan): string | null {
    const trimmed = span.trimLeft();
    if (trimmed.length === 0) return null;

    const trimmedText = trimmed.text;
    return trimmedText.at(0) === ';' ? trimmedText.substring(1) : null;
  }
}

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
      this.raws = new LazyRootRaws(inner);
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
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}
