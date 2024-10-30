// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {CommentRaws} from 'postcss/lib/comment';

import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import {Interpolation} from '../interpolation';
import * as utils from '../utils';
import {ContainerProps, Statement, StatementWithChildren} from '.';
import {_Comment} from './comment-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link SassComment}.
 *
 * @category Statement
 */
export interface SassCommentRaws extends Omit<CommentRaws, 'right'> {
  /**
   * Unlike PostCSS's, `CommentRaws.before`, this is added before `//` for
   * _every_ line of this comment. If any lines have more indentation than this,
   * it appears in {@link beforeLines} instead.
   */
  before?: string;

  /**
   * For each line in the comment, this is the whitespace that appears before
   * the `//` _in addition to_ {@link before}.
   */
  beforeLines?: string[];

  /**
   * Unlike PostCSS's `CommentRaws.left`, this is added after `//` for _every_
   * line in the comment that's not only whitespace. If any lines have more
   * initial whitespace than this, it appears in {@link SassComment.text}
   * instead.
   *
   * Lines that are only whitespace do not have `left` added to them, and
   * instead have all their whitespace directly in {@link SassComment.text}.
   */
  left?: string;
}

/**
 * The subset of {@link SassCommentProps} that can be used to construct it
 * implicitly without calling `new SassComment()`.
 *
 * @category Statement
 */
export type SassCommentChildProps = ContainerProps & {
  raws?: SassCommentRaws;
  silentText: string;
};

/**
 * The initializer properties for {@link SassComment}.
 *
 * @category Statement
 */
export type SassCommentProps = ContainerProps & {
  raws?: SassCommentRaws;
} & (
    | {
        silentText: string;
      }
    | {text: string}
  );

/**
 * A Sass-style "silent" comment. Extends [`postcss.Comment`].
 *
 * [`postcss.Comment`]: https://postcss.org/api/#comment
 *
 * @category Statement
 */
export class SassComment
  extends _Comment<Partial<SassCommentProps>>
  implements Statement
{
  readonly sassType = 'sass-comment' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: SassCommentRaws;

  /**
   * The text of this comment, potentially spanning multiple lines.
   *
   * This is always the same as {@link text}, it just has a different name to
   * distinguish {@link SassCommentProps} from {@link CssCommentProps}.
   */
  declare silentText: string;

  get text(): string {
    return this.silentText;
  }
  set text(value: string) {
    this.silentText = value;
  }

  constructor(defaults: SassCommentProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.SilentComment);
  constructor(defaults?: SassCommentProps, inner?: sassInternal.SilentComment) {
    super(defaults as unknown as postcss.CommentProps);

    if (inner) {
      this.source = new LazySource(inner);

      const lineInfo = inner.text
        .trimRight()
        .split('\n')
        .map(line => {
          const index = line.indexOf('//');
          const before = line.substring(0, index);
          const regexp = /[^ \t]/g;
          regexp.lastIndex = index + 2;
          const firstNonWhitespace = regexp.exec(line)?.index;
          if (firstNonWhitespace === undefined) {
            return {before, left: null, text: line.substring(index + 2)};
          }

          const left = line.substring(index + 2, firstNonWhitespace);
          const text = line.substring(firstNonWhitespace);
          return {before, left, text};
        });

      // Dart Sass doesn't include the whitespace before the first `//` in
      // SilentComment.text, so we grab it directly from the SourceFile.
      let i = inner.span.start.offset - 1;
      for (; i >= 0; i--) {
        const char = inner.span.file.codeUnits[i];
        if (char !== 0x20 && char !== 0x09) break;
      }
      lineInfo[0].before = inner.span.file.getText(
        i + 1,
        inner.span.start.offset
      );

      const before = (this.raws.before = utils.longestCommonInitialSubstring(
        lineInfo.map(info => info.before)
      ));
      this.raws.beforeLines = lineInfo.map(info =>
        info.before.substring(before.length)
      );
      const left = (this.raws.left = utils.longestCommonInitialSubstring(
        lineInfo.map(info => info.left).filter(left => left !== null)
      ));
      this.text = lineInfo
        .map(info => (info.left?.substring(left.length) ?? '') + info.text)
        .join('\n');
    }
  }

  clone(overrides?: Partial<SassCommentProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'silentText'], ['text']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['text', 'text'], inputs);
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    return [];
  }
}

interceptIsClean(SassComment);
