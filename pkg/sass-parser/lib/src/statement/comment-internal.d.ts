// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Root} from './root';
import {ChildNode, NewNode} from '.';

/**
 * A fake intermediate class to convince TypeScript to use Sass types for
 * various upstream methods.
 *
 * @hidden
 */
export class _Comment<Props> extends postcss.Comment {
  // Override the PostCSS types to constrain them to Sass types only.
  // Unfortunately, there's no way to abstract this out, because anything
  // mixin-like returns an intersection type which doesn't actually override
  // parent methods. See microsoft/TypeScript#59394.

  after(newNode: NewNode): this;
  assign(overrides: Partial<Props>): this;
  before(newNode: NewNode): this;
  cloneAfter(overrides?: Partial<Props>): this;
  cloneBefore(overrides?: Partial<Props>): this;
  next(): ChildNode | undefined;
  prev(): ChildNode | undefined;
  replaceWith(...nodes: NewNode[]): this;
  root(): Root;
}
