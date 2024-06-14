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
  private readonly _inner: sassInternal.SassNode;

  constructor(inner: sassInternal.SassNode) {
    this._inner = inner;
  }

  private _start: postcss.Position | undefined | 0 = 0;
  get start(): postcss.Position | undefined {
    if (this._start === 0) {
      this._start = locationToPosition(this._inner.span.start);
    }
    return this._start;
  }
  set start(value: postcss.Position | undefined) {
    this._start = value;
  }

  private _end: postcss.Position | undefined | 0 = 0;
  get end(): postcss.Position | undefined {
    if (this._end === 0) {
      this._end = locationToPosition(this._inner.span.end);
    }
    return this._end;
  }
  set end(value: postcss.Position | undefined) {
    this._end = value;
  }

  private _input: postcss.Input | null = null;
  get input(): postcss.Input {
    const spanUrl = this._inner.span.url;
    this._input ??= new postcss.Input(
      (this._inner.span as sassInternal.FileSpan).file.getText(0),
      spanUrl ? {from: url.fileURLToPath(spanUrl)} : undefined
    );
    return this._input;
  }
  set input(value: postcss.Input) {
    this._input = value;
  }
}

/** Converts a Sass SourceLocation to a PostCSS Position. */
function locationToPosition(location: sass.SourceLocation): postcss.Position {
  return {
    line: location.line + 1,
    column: location.column + 1,
    offset: location.offset,
  };
}
