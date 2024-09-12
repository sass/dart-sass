// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

const postcss = require('postcss');

// Define this separately from the declaration so that we can have it inherit
// all the methods of the base class and make a few of them throw without it
// showing up in the TypeScript types.
class Node extends postcss.Node {
  constructor(defaults = {}) {
    super(defaults);
  }

  after() {
    throw new Error("after() is only supported for Sass statement nodes.");
  }

  before() {
    throw new Error("before() is only supported for Sass statement nodes.");
  }

  cloneAfter() {
    throw new Error("cloneAfter() is only supported for Sass statement nodes.");
  }

  cloneBefore() {
    throw new Error("cloneBefore() is only supported for Sass statement nodes.");
  }

  next() {
    throw new Error("next() is only supported for Sass statement nodes.");
  }

  prev() {
    throw new Error("prev() is only supported for Sass statement nodes.");
  }

  remove() {
    throw new Error("remove() is only supported for Sass statement nodes.");
  }

  replaceWith() {
    throw new Error("replaceWith() is only supported for Sass statement nodes.");
  }
}
exports.Node = Node;
