// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {AnyExpression} from '../expression';
import {Interpolation} from '../interpolation';
import * as sassInternal from '../sass-internal';

/**
 * An object that tracks all the interpolations that were pulled out of a
 * selector before parsing and injects them back into the plain strings that
 * were parsed.
 */
export class InterpolationInjector {
  /**
   * The placeholder string that was used to replace interpolated expressions
   * in the text that was parsed.
   */
  readonly #replacement: string;

  /** The expressions in the original interpolation. */
  readonly #expressions: AnyExpression[];

  private constructor(replacement: string, expressions: AnyExpression[]) {
    this.#replacement = replacement;
    this.#expressions = expressions;
  }

  /**
   * Extracts expressions from an {@link Interpolation} and returns:
   *
   * * a string with those expressions replaced with plain identifiers
   * * a {@link * sassInternal.InterpolationMap} that can be used to generate accurate
   *   source spans when parsing that string, and
   * * a {@link InterpolationInjector} that can recreate {@link Interpolation}
   *   objects for parsed subsets of that string.
   */
  static extract(
    interpolation: Interpolation,
  ): [string, sassInternal.InterpolationMap, InterpolationInjector] {
    // Replace all interpolations in the selector with a string that's valid
    // anywhere in an identifier. On the very slim chance that the selector
    // already contains something that looks like this string, increment a
    // number to avoid that conflict.
    let replacement: string;
    for (let i = 0; ; i++) {
      replacement = `__interpolation${i}__`;
      if (
        !interpolation.nodes.some(
          value => typeof value === 'string' && value.includes(replacement),
        )
      ) {
        break;
      }
    }

    let parseable = '';
    // TODO: also preserve the raws from the original interpolation
    // expressions
    const targetOffsets: number[] = [];
    const expressions: AnyExpression[] = [];
    for (const value of interpolation.nodes) {
      if (typeof value === 'string') {
        parseable += value;
      } else {
        parseable += replacement;
        expressions.push(value);
      }
      targetOffsets.push(parseable.length);
    }

    return [
      parseable,
      sassInternal.createInterpolationMap(
        interpolation.toDartInterpolationForMap(),
        targetOffsets,
      ),
      new InterpolationInjector(replacement, expressions),
    ];
  }

  /**
   * Converts {@link text} into an {@link Interpolation} by injecting the
   * stored expressions into it in place of the placeholder strings.
   *
   * This should be called on strings in the lexical order in which they
   * appeared in the original parse.
   */
  inject(text: string): Interpolation {
    const nodes: Array<string | AnyExpression> = [];
    let startIndex = 0;
    for (;;) {
      const index = text.indexOf(this.#replacement, startIndex);
      if (index === -1) break;
      const previousString = text.substring(startIndex, index);
      startIndex = index + this.#replacement.length;

      if (previousString !== '') nodes.push(previousString);
      const expression = this.#expressions.shift();
      if (!expression) {
        throw new Error(
          'InterpolationInjector.inject() found more replacement ' +
            'expressions than interpolations',
        );
      }
      nodes.push(expression);
    }

    const finalString = text.substring(startIndex);
    if (finalString !== '') nodes.push(finalString);

    // TODO: set proper source information here, probably using a LazySource
    // that points to a span generated on the Dart side (which we'll have to
    // pass in to this function).
    return new Interpolation(nodes);
  }
}
