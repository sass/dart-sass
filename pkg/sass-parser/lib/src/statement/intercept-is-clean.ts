// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {isClean} from '../postcss';
import type {Node} from '../node';
import * as utils from '../utils';
import type {Statement} from '.';

/**
 * Defines a getter/setter pair for the given {@link klass} that intercepts
 * PostCSS's attempt to mark it as clean and marks any non-statement children as
 * clean as well.
 */
export function interceptIsClean<T extends Statement>(
  klass: utils.Constructor<T>
): void {
  Object.defineProperty(klass as typeof klass & {_isClean: boolean}, isClean, {
    get(): boolean {
      return this._isClean;
    },
    set(value: boolean): void {
      this._isClean = value;
      if (value) this.nonStatementChildren.forEach(markClean);
    },
  });
}

/** Marks {@link node} and all its children as clean. */
function markClean(node: Node): void {
  (node as Node & {[isClean]: boolean})[isClean] = true;
  node.nonStatementChildren.forEach(markClean);
}
