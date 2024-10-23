// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/**
 * An object describing how a value is represented in a stylesheet's source.
 *
 * This is used for values that can have multiple different representations that
 * all produce the same value. The {@link raw} field indicates the textual
 * representation in the stylesheet, while the {@link value} indicates the value
 * it represents.
 *
 * When serializing, if {@link value} doesn't match the value in the AST node,
 * this is ignored. This ensures that if a plugin overwrites the AST value
 * and ignores the raws, its change is preserved in the serialized output.
 */
export interface RawWithValue<T> {
  /** The textual representation of {@link value} in the stylesheet. */
  raw: string;

  /**
   * The parsed value that {@link raw} represents. This is used to verify that
   * this raw is still valid for the AST node that contains it.
   */
  value: T;
}
