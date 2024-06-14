// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {LazySource} from './lazy-source';
import type * as sassInternal from './sass-internal';

/** The root node of a Sass stylesheet. */
export class Root extends postcss.Root {
  constructor(defaults?: object, inner?: sassInternal.Stylesheet) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
    }
  }
}
