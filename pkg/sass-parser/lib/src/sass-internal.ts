// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sass from 'sass';

// Type definitions for internal Sass APIs we're wrapping. We cast the Sass
// module to this type to access them.

export type Syntax = 'scss' | 'sass' | 'css';

export interface FileSpan extends sass.SourceSpan {
  readonly file: SourceFile;
}

export interface SourceFile {
  getText(start: number, end?: number): string;
}

// There may be a better way to declare this, but I can't figure it out.
// eslint-disable-next-line @typescript-eslint/no-namespace
declare namespace SassInternal {
  function parse(
    css: string,
    syntax: Syntax,
    path?: string,
    logger?: sass.Logger
  ): Stylesheet;

  class SassNode {
    readonly span: sass.SourceSpan;
  }

  class Interpolation extends SassNode {
    contents: (string|Expression)[];
    get asPlain(): string|undefined;
  }

  class Statement extends SassNode {}

  class ParentStatement<T extends Statement[] | null> extends Statement {
    readonly children: T;
  }

  class Stylesheet extends ParentStatement<Statement[]> {}

  class StyleRule extends ParentStatement<Statement[]> {}

  class Expression extends SassNode {}
}

const sassInternal = (
  sass as unknown as {loadParserExports_(): typeof SassInternal}
).loadParserExports_();

export type SassNode = SassInternal.SassNode;

export type Statement = SassInternal.Statement;

export type ParentStatement<T extends Statement[] | null> =
  SassInternal.ParentStatement<T>;

export type Stylesheet = SassInternal.Stylesheet;

export type StyleRule = SassInternal.StyleRule;
export const StyleRule = sassInternal.StyleRule;

export const parse = sassInternal.parse;
