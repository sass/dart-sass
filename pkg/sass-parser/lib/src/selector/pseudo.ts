// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Interpolation, InterpolationProps} from '../interpolation';
import {LazySource} from '../lazy-source';
import type {AnyNode, NodeProps} from '../node';
import type {AnyStatement} from '../statement';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {SelectorList, SelectorListProps} from './list';
import {SimpleSelector} from './index';

/**
 * The initializer properties for {@link PseudoSelector}.
 *
 * @category Selector
 */
export type PseudoSelectorProps = NodeProps & {
  pseudo: Interpolation | InterpolationProps;
  argument?: Interpolation | InterpolationProps;
  selector?: SelectorList | SelectorListProps;
  raws?: PseudoSelectorRaws;
} & ({isClass?: boolean} | {isElement?: boolean});

/**
 * Raws indicating how to precisely serialize a {@PseudoSelector}.
 *
 * @category Selector
 */
export interface PseudoSelectorRaws {
  /**
   * The whitespace after the opening parenthesis in the selector's argument.
   *
   * This is ignored unless {@link PseudoSelector.argument} and/or {@link
   * PseudoSelector.selector} is defined.
   */
  afterOpen?: string;

  /**
   * The whitespace before the closing parenthesis in the selector's argument.
   *
   * This is ignored unless {@link PseudoSelector.argument} and/or {@link
   * PseudoSelector.selector} is defined.
   */
  beforeClose?: string;

  /**
   * The whitespace between {@link PseudoSelector.argument} and {#link
   * PseudoSelector.selector}.
   *
   * This is ignored unless {@link PseudoSelector.argument} is defined.
   * It's not assigned by default unless both {@link
   * PseudoSelector.argument} and {@link PseudoSelector.selector} are
   * both defined.
   */
  afterArgument?: string;
}

/**
 * A pseudo-class or pseudo-element selector.
 *
 * The semantics of a specific pseudo selector depends on its name. Some
 * selectors take arguments, including other selectors.
 *
 * @category Selector
 */
export class PseudoSelector extends SimpleSelector {
  readonly sassType = 'pseudo' as const;
  declare raws: PseudoSelectorRaws;

  /** The name of the pseudo-selector or pseudo-element. */
  get pseudo(): Interpolation {
    return this._pseudo;
  }
  set pseudo(pseudo: Interpolation | InterpolationProps) {
    if (this._pseudo) this._pseudo.parent = undefined;
    const built =
      typeof pseudo === 'object' && 'sassType' in pseudo
        ? pseudo
        : new Interpolation(pseudo);
    built.parent = this;
    this._pseudo = built;
  }
  declare private _pseudo: Interpolation;

  /**
   * Whether this is syntactically written as a pseudo-class (as opposed to a
   * pseudo-element).
   *
   * This defaults to `true`.
   */
  get isClass(): boolean {
    return !this._isElement;
  }
  set isClass(isClass: boolean) {
    this._isElement = !isClass;
  }

  /**
   * Whether this is syntactically written as a pseudo-element (as opposed to a
   * pseudo-class).
   *
   * This defaults to `false`.
   */
  get isElement(): boolean {
    return this._isElement;
  }
  set isElement(isElement: boolean) {
    this._isElement = isElement;
  }
  declare private _isElement: boolean;

  /**
   * The non-selector argument passed to this selector.
   *
   * This is `undefined` if there's no argument. If {@link argument} and {@link
   * selector} are both non-`undefined`, the selector follows the argument.
   */
  get argument(): Interpolation | undefined {
    return this._argument;
  }
  set argument(argument: Interpolation | InterpolationProps | undefined) {
    if (this._argument) this._argument.parent = undefined;
    const built =
      argument === undefined
        ? undefined
        : typeof argument === 'object' && 'sassType' in argument
          ? argument
          : new Interpolation(argument);
    if (built) built.parent = this;
    this._argument = built;
  }
  declare private _argument: Interpolation | undefined;

  /**
   * The non-selector argument passed to this selector.
   *
   * This is `undefined` if there's no argument. If {@link argument} and {@link
   * selector} are both non-`undefined`, the selector follows the argument.
   */
  get selector(): SelectorList | undefined {
    return this._selector;
  }
  set selector(selector: SelectorList | SelectorListProps | undefined) {
    if (this._selector) this._selector.parent = undefined;
    const built =
      selector === undefined
        ? undefined
        : 'sassType' in selector && selector.sassType === 'selector-list'
          ? selector
          : new SelectorList(selector);
    if (built) built.parent = this;
    this._selector = built;
  }
  declare private _selector: SelectorList | undefined;

  constructor(defaults: PseudoSelectorProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.PseudoSelector);
  constructor(defaults?: object, inner?: sassInternal.PseudoSelector) {
    super(defaults);
    this._isElement ??= false;
    if (inner) {
      this.source = new LazySource(inner);
      this.pseudo = new Interpolation(undefined, inner.name);
      this.isClass = inner.isSyntacticClass;
      if (inner.argument)
        this.argument = new Interpolation(undefined, inner.argument);
      if (inner.selector) {
        this.selector = new SelectorList(undefined, inner.selector);
      }
    }
  }

  clone(overrides?: Partial<PseudoSelectorProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      [
        'raws',
        'pseudo',
        'isElement',
        {name: 'argument', explicitUndefined: true},
        {name: 'selector', explicitUndefined: true},
      ],
      ['isClass'],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['pseudo', 'isElement', 'argument', 'selector'],
      inputs,
    );
  }

  /** @hidden */
  toString(): string {
    let result = (this.isElement ? '::' : ':') + this.pseudo;
    if (this.argument || this.selector) {
      result += `(${this.raws.afterOpen ?? ''}`;
    }
    if (this.argument) {
      result +=
        this.argument + (this.raws.afterArgument ?? (this.selector ? ' ' : ''));
    }
    if (this.selector) result += this.selector;
    if (this.argument || this.selector) {
      result += `${this.raws.beforeClose ?? ''})`;
    }
    return result;
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Exclude<AnyNode, AnyStatement>> {
    const result: Array<Exclude<AnyNode, AnyStatement>> = [this.pseudo];
    if (this.argument) result.push(this.argument);
    if (this.selector) result.push(this.selector);
    return result;
  }
}
