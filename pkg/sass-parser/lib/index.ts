// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import * as sassApi from 'sass';

import {Root} from './src/root';
import * as sassInternal from './src/sass-internal';

/** Options that can be passed to the Sass parsers to control their behavior. */
interface SassParserOptions
  extends Pick<postcss.ProcessOptions, 'from' | 'map'> {
  /** The logger that's used to log messages encountered during parsing. */
  logger?: sassApi.Logger;
}

/** A PostCSS syntax for parsing a particular Sass syntax. */
class Syntax implements postcss.Syntax<postcss.Root> {
  /** The syntax with which to parse stylesheets. */
  private readonly _syntax: sassInternal.Syntax;

  constructor(syntax: sassInternal.Syntax) {
    this._syntax = syntax;
  }

  parse(css: {toString(): string} | string, opts?: SassParserOptions): Root {
    if (opts?.map) {
      // We might be able to support this as a layer on top of source spans, but
      // is it worth the effort?
      throw "sass-parser doesn't currently support consuming source maps.";
    }

    return new Root(
      undefined,
      sassInternal.parse(css.toString(), this._syntax, opts?.from, opts?.logger)
    );
  }

  stringify(node: postcss.AnyNode, builder: postcss.Builder): void {
    throw 'unsupported';
  }
}

/** A PostCSS syntax for parsing SCSS. */
export const scss: postcss.Syntax<postcss.Root> = new Syntax('scss');

/** A PostCSS syntax for parsing Sass's indented syntax. */
export const sass: postcss.Syntax<postcss.Root> = new Syntax('sass');

/** A PostCSS syntax for parsing plain CSS. */
export const css: postcss.Syntax<postcss.Root> = new Syntax('css');
