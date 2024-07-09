// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

declare module 'postcss' {
  interface Container<Child extends postcss.Node = postcss.ChildNode> {
    // We need to be able to override this and call it as a super method.
    // TODO - postcss/postcss#1957: Remove this
    /** @hidden */
    normalize(
      node: string | postcss.ChildProps | postcss.Node,
      sample: postcss.Node | undefined
    ): Child[];
  }
}

export const isClean: unique symbol;
