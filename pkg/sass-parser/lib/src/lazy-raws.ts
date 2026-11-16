// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import type * as util from 'node:util';

import * as sassInternal from './sass-internal';

/**
 * A base class for PostCSS-compatible raws that are lazily computed from the
 * original Sass node's source spans on first access. This ensures that
 * relatively-expensive span manipulation is only done when necessary to
 * reserialize nodes with the same formatting.
 *
 * Subclasses must define a constructor with `T` as its only argument.
 */
export abstract class LazyRaws<T extends sassInternal.SassNode> {
  /** The AST node from whose span(s) we determine the raws. */
  declare protected readonly _node: T;

  /** An inner record of raws to their values. */
  #inner: Record<string, unknown> = {};

  /**
   * Creates a new set of raws. {@link fields} must be the names of all fields
   * set by {@link _computeRaws}.
   */
  constructor(node: T, fields: string[]) {
    Object.defineProperty(this, '_node', {
      enumerable: false,
      writable: false,
      value: node,
    });

    const props: Record<string, PropertyDescriptor> = {};
    for (const field of fields) {
      this.#inner[field] = null;
      props[field] = {
        enumerable: true,
        get: function (this: LazyRaws<T>): unknown {
          if (this.#inner[field] === null) this._computeRaws();
          return this.#inner[field] ?? undefined;
        },
        set: function (this: LazyRaws<T>, value: unknown) {
          this.#inner[field] = value;
        },
      };
    }

    Object.defineProperties(this, props);
  }

  /**
   * A wrapper for {@link _computeRaws} that avoids recomputing if all the raws
   * already have values.
   */
  #computeRaws(): void {
    if (!Object.values(this.#inner).includes(null)) return;
    this._computeRaws();
  }

  /**
   * Uses {@link _setRawDefault} to set the raws based on {@link _node}'s source
   * spans. This is only called when a raw is accessed by the user without first
   * being set. It's expected to set *all* raws.
   */
  protected abstract _computeRaws(): void;

  /**
   * Creates a copy of this, preserving any raws that have been set or computed.
   */
  _clone(): this {
    const result = new (this.constructor as new (node: T) => this)(this._node);
    result.#inner = structuredClone(this.#inner);
    return result;
  }

  /**
   * If {@link name} hasn't been set explicitly by the user, calls {@link
     callback} and sets {@link name} to its result.
   */
  protected _setRawDefault(name: string, callback: () => unknown): void {
    if (this.#inner[name] !== null) return;
    this.#inner[name] = callback();
  }

  /** Make this look like a normal object when inspected in Node.js. */
  [Symbol.for('util.inspect.custom')](
    _: number,
    options: util.InspectOptions,
  ): string {
    this.#computeRaws();
    // We assume that if this is being called, Node.js is in fact available (or
    // `util` is polyfilled at the bundler level).
    return require('util').inspect(this.#inner, options);
  }
}
