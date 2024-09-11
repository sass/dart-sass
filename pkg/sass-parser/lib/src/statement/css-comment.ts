// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {CommentRaws} from 'postcss/lib/comment';

import {convertExpression} from '../expression/convert';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import {Interpolation} from '../interpolation';
import * as utils from '../utils';
import {ContainerProps, Statement, StatementWithChildren} from '.';
import {_Comment} from './comment-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link CssComment}.
 *
 * @category Statement
 */
export interface CssCommentRaws extends CommentRaws {
  /**
   * In the indented syntax, this indicates whether a comment is explicitly
   * closed with a `*\/`. It's ignored in other syntaxes.
   *
   * It defaults to false.
   */
  closed?: boolean;
}

/**
 * The initializer properties for {@link CssComment}.
 *
 * @category Statement
 */
export type CssCommentProps = ContainerProps & {
  raws?: CssCommentRaws;
} & ({text: string} | {textInterpolation: Interpolation | string});

/**
 * A CSS-style "loud" comment. Extends [`postcss.Comment`].
 *
 * [`postcss.Comment`]: https://postcss.org/api/#comment
 *
 * @category Statement
 */
export class CssComment
  extends _Comment<Partial<CssCommentProps>>
  implements Statement
{
  readonly sassType = 'comment' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: CssCommentRaws;

  get text(): string {
    return this.textInterpolation.toString();
  }
  set text(value: string) {
    this.textInterpolation = value;
  }

  /** The interpolation that represents this selector's contents. */
  get textInterpolation(): Interpolation {
    return this._textInterpolation!;
  }
  set textInterpolation(textInterpolation: Interpolation | string) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._textInterpolation) {
      this._textInterpolation.parent = undefined;
    }
    if (typeof textInterpolation === 'string') {
      textInterpolation = new Interpolation({
        nodes: [textInterpolation],
      });
    }
    textInterpolation.parent = this;
    this._textInterpolation = textInterpolation;
  }
  private _textInterpolation?: Interpolation;

  constructor(defaults: CssCommentProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.LoudComment);
  constructor(defaults?: CssCommentProps, inner?: sassInternal.LoudComment) {
    super(defaults as unknown as postcss.CommentProps);

    if (inner) {
      this.source = new LazySource(inner);
      const nodes = [...inner.text.contents];

      // The interpolation's contents are guaranteed to begin with a string,
      // because Sass includes the `/*`.
      let first = nodes[0] as string;
      const firstMatch = first.match(/^\/\*([ \t\n\r\f]*)/)!;
      this.raws.left ??= firstMatch[1];
      first = first.substring(firstMatch[0].length);
      if (first.length === 0) {
        nodes.shift();
      } else {
        nodes[0] = first;
      }

      // The interpolation will end with `*/` in SCSS, but not necessarily in
      // the indented syntax.
      let last = nodes.at(-1);
      if (typeof last === 'string') {
        const lastMatch = last.match(/([ \t\n\r\f]*)\*\/$/);
        this.raws.right ??= lastMatch?.[1] ?? '';
        this.raws.closed = !!lastMatch;
        if (lastMatch) {
          last = last.substring(0, last.length - lastMatch[0].length);
          if (last.length === 0) {
            nodes.pop();
          } else {
            nodes[0] = last;
          }
        }
      } else {
        this.raws.right ??= '';
        this.raws.closed = false;
      }

      this.textInterpolation = new Interpolation();
      for (const child of nodes) {
        this.textInterpolation.append(
          typeof child === 'string' ? child : convertExpression(child)
        );
      }
    }
  }

  clone(overrides?: Partial<CssCommentProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      ['raws', 'textInterpolation'],
      ['text']
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['text', 'textInterpolation'], inputs);
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
    return [this.textInterpolation];
  }
}

interceptIsClean(CssComment);
