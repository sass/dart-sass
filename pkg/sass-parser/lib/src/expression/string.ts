// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Interpolation} from '../interpolation';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {Expression} from '.';

/**
 * The initializer properties for {@link StringExpression}.
 *
 * @category Expression
 */
export interface StringExpressionProps {
  text: Interpolation | string;
  quotes?: boolean;
  raws?: StringExpressionRaws;
}

/**
 * Raws indicating how to precisely serialize a {@link StringExpression}.
 *
 * @category Expression
 */
export interface StringExpressionRaws {
  /**
   * The type of quotes to use (single or double).
   *
   * This is ignored if the string isn't quoted.
   */
  quotes?: '"' | "'";
}

/**
 * An expression representing a (quoted or unquoted) string literal in Sass.
 *
 * @category Expression
 */
export class StringExpression extends Expression {
  readonly sassType = 'string' as const;
  declare raws: StringExpressionRaws;

  /** The interpolation that represents the text of this string. */
  get text(): Interpolation {
    return this._text;
  }
  set text(text: Interpolation | string) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    if (this._text) this._text.parent = undefined;
    if (typeof text === 'string') text = new Interpolation({nodes: [text]});
    text.parent = this;
    this._text = text;
  }
  private _text!: Interpolation;

  // TODO: provide a utility asPlainIdentifier method that returns the value of
  // an identifier with any escapes resolved, if this is indeed a valid unquoted
  // identifier.

  /**
   * Whether this is a quoted or unquoted string. Defaults to false.
   *
   * Unquoted strings are most commonly used to represent identifiers, but they
   * can also be used for string-like functions such as `url()` or more unusual
   * constructs like Unicode ranges.
   */
  get quotes(): boolean {
    return this._quotes;
  }
  set quotes(quotes: boolean) {
    // TODO - postcss/postcss#1957: Mark this as dirty
    this._quotes = quotes;
  }
  private _quotes!: boolean;

  constructor(defaults: StringExpressionProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.StringExpression);
  constructor(defaults?: object, inner?: sassInternal.StringExpression) {
    super(defaults);
    if (inner) {
      this.source = new LazySource(inner);
      this.text = new Interpolation(undefined, inner.text);
      this.quotes = inner.hasQuotes;
    } else {
      this._quotes ??= false;
    }
  }

  clone(overrides?: Partial<StringExpressionProps>): this {
    return utils.cloneNode(this, overrides, ['raws', 'text', 'quotes']);
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(this, ['text', 'quotes'], inputs);
  }

  /** @hidden */
  toString(): string {
    const quote = this.quotes ? this.raws.quotes ?? '"' : '';
    let result = quote;
    const rawText = this.text.raws.text;
    const rawExpressions = this.text.raws.expressions;
    for (let i = 0; i < this.text.nodes.length; i++) {
      const element = this.text.nodes[i];
      if (typeof element === 'string') {
        const raw = rawText?.[i];
        // The Dart Sass AST preserves string escapes for unquoted strings
        // because they serve a dual purpose at runtime of representing
        // identifiers (which may contain escape codes) and being a catch-all
        // representation for unquoted non-identifier values such as `url()`s.
        // As such, escapes in unquoted strings are represented literally.
        result +=
          raw?.value === element
            ? raw.raw
            : this.quotes
              ? this.#escapeQuoted(element)
              : element;
      } else {
        const raw = rawExpressions?.[i];
        result +=
          '#{' + (raw?.before ?? '') + element + (raw?.after ?? '') + '}';
      }
    }
    return result + quote;
  }

  /** Escapes a text component of a quoted string literal. */
  #escapeQuoted(text: string): string {
    const quote = this.raws.quotes ?? '"';
    let result = '';
    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      switch (char) {
        case '"':
          result += quote === '"' ? '\\"' : '"';
          break;

        case "'":
          result += quote === "'" ? "\\'" : "'";
          break;

        // Write newline characters and unprintable ASCII characters as escapes.
        case '\x00':
        case '\x01':
        case '\x02':
        case '\x03':
        case '\x04':
        case '\x05':
        case '\x06':
        case '\x07':
        case '\x08':
        case '\x09':
        case '\x0A':
        case '\x0B':
        case '\x0C':
        case '\x0D':
        case '\x0E':
        case '\x0F':
        case '\x10':
        case '\x11':
        case '\x12':
        case '\x13':
        case '\x14':
        case '\x15':
        case '\x16':
        case '\x17':
        case '\x18':
        case '\x19':
        case '\x1A':
        case '\x1B':
        case '\x1C':
        case '\x1D':
        case '\x1E':
        case '\x1F':
        case '\x7F':
          result += '\\' + char.charCodeAt(0).toString(16) + ' ';
          break;

        case '\\':
          result += '\\\\';
          break;

        default:
          result += char;
          break;
      }
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Interpolation> {
    return [this.text];
  }
}
