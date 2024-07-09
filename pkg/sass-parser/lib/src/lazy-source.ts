// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sass from 'sass';
import * as postcss from 'postcss';
import * as url from 'url';

import type * as sassInternal from './sass-internal';

/**
 * An implementation of `postcss.Source` that lazily fills in the fields when
 * they're first accessed.
 */
export class LazySource implements postcss.Source {
  /**
   * The Sass node whose source this covers. We store the whole node rather than
   * just the span becasue the span itself may be computed lazily.
   */
  readonly #inner: sassInternal.SassNode;

  constructor(inner: sassInternal.SassNode) {
    this.#inner = inner;
  }

  get start(): postcss.Position | undefined {
    if (this.#start === 0) {
      this.#start = locationToPosition(this.#inner.span.start);
    }
    return this.#start;
  }
  set start(value: postcss.Position | undefined) {
    this.#start = value;
  }
  #start: postcss.Position | undefined | 0 = 0;

  get end(): postcss.Position | undefined {
    if (this.#end === 0) {
      this.#end = locationToPosition(this.#inner.span.end);
    }
    return this.#end;
  }
  set end(value: postcss.Position | undefined) {
    this.#end = value;
  }
  #end: postcss.Position | undefined | 0 = 0;

  get input(): postcss.Input {
    if (this.#input) return this.#input;

    const sourceFile = this.#inner.span.file;
    if (sourceFile._postcssInput) return sourceFile._postcssInput;

    const spanUrl = this.#inner.span.url;
    sourceFile._postcssInput = new postcss.Input(
      sourceFile.getText(0),
      spanUrl ? {from: url.fileURLToPath(spanUrl)} : undefined
    );
    return sourceFile._postcssInput;
  }
  set input(value: postcss.Input) {
    this.#input = value;
  }
  #input: postcss.Input | null = null;
}

/** Converts a Sass SourceLocation to a PostCSS Position. */
function locationToPosition(location: sass.SourceLocation): postcss.Position {
  return {
    line: location.line + 1,
    column: location.column + 1,
    offset: location.offset,
  };
}
