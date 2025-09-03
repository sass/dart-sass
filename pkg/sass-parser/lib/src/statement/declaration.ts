// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import type {DeclarationRaws as PostcssDeclarationRaws} from 'postcss/lib/declaration';

import {AnyExpression, ExpressionProps} from '../expression';
import {Interpolation, InterpolationProps} from '../interpolation';
import {convertExpression} from '../expression/convert';
import {fromProps} from '../expression/from-props';
import {LazySource} from '../lazy-source';
import * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {
  ChildNode,
  ChildProps,
  ContainerProps,
  NewNode,
  Statement,
  StatementWithChildren,
  appendInternalChildren,
  normalize,
} from '.';
import {_DeclarationWithChildren} from './declaration-internal';
import * as sassParser from '../..';

// TODO(nweiz): Make sure setting non-identifier strings for prop here and name
// in GenericAtRule escapes properly.

/**
 * The set of raws supported by {@link Declaration}.
 *
 * @category Statement
 */
export interface DeclarationRaws
  extends Omit<PostcssDeclarationRaws, 'value' | 'important'> {
  /**
   * The space symbols between the end of the declaration's value and the
   * semicolon or the opening `{`. Always empty for a declaration that isn't
   * followed by a semicolon, and ignored if the declaration has children but no
   * value.
   */
  afterValue?: string;

  /**
   * The space symbols between the last child of the node and the `}`. Ignored
   * if the declaration has no children.
   */
  after?: string;

  /**
   * The text of the semicolon after the declaration's children. Ignored if the
   * declaration has no children.
   */
  ownSemicolon?: string;

  /**
   * Contains `true` if the last child has an (optional) semicolon. Ignored if
   * the declaration has no children.
   */
  semicolon?: boolean;
}

/**
 * The initializer properties for {@link Declaration}.
 *
 * @category Statement
 */
export type DeclarationProps = ContainerProps & {
  raws?: DeclarationRaws;
} & (
    | {propInterpolation: Interpolation | InterpolationProps; prop?: never}
    | {prop: string; propInterpolation?: never}
  ) &
  (
    | {expression: AnyExpression | ExpressionProps; value?: never}
    | {value: string; expression?: never}
    // `expression` and `value` are optional, but *only* if `nodes` is passed
    // explicitly. This also allows `nodes` to be passed along with
    // `expressions` or `values` because of the top-level `ContainerProps &`.
    | {nodes: ReadonlyArray<postcss.Node | ChildProps>}
  );

/**
 * A Sass property declaration. Extends [`postcss.Declaration`].
 *
 * [`postcss.Declaration`]: https://postcss.org/api/#declaration
 *
 * @category Statement
 */
export class Declaration
  extends _DeclarationWithChildren<Partial<DeclarationProps>>
  implements Statement
{
  readonly sassType = 'decl' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: DeclarationRaws;
  declare nodes: ChildNode[] | undefined;

  get prop(): string {
    return this.propInterpolation.toString();
  }
  set prop(value: string) {
    this.propInterpolation = value;
  }

  /**
   * The interpolation that represents this declaration's property name.
   */
  get propInterpolation(): Interpolation {
    return this._propInterpolation!;
  }
  set propInterpolation(value: Interpolation | InterpolationProps) {
    if (this._propInterpolation) this._propInterpolation.parent = undefined;
    const propInterpolation =
      value instanceof Interpolation ? value : new Interpolation(value);
    propInterpolation.parent = this;
    this._propInterpolation = propInterpolation;
  }
  private declare _propInterpolation?: Interpolation;

  /**
   * The declaration's value.
   *
   * **Note:** In Sass, custom properties can't have SassScript values without
   * being surrounded by interpolation. Custom properties are always parsed as
   * unquoted string values, and if they're set to other SassScript values they
   * may not be evaluated as expected.
   */
  get expression(): AnyExpression | undefined {
    return this._expression;
  }
  set expression(value: AnyExpression | ExpressionProps | undefined) {
    if (this._expression) this._expression.parent = undefined;
    if (!value) {
      this._expression = undefined;
    } else {
      const built = 'sassType' in value ? value : fromProps(value);
      built.parent = this;
      this._expression = built;
    }
  }
  private declare _expression?: AnyExpression;

  get value(): string {
    return this.expression?.toString() ?? '';
  }
  set value(value: string | undefined) {
    this.expression = value === undefined ? undefined : {text: value};
  }

  get important(): boolean {
    // TODO: Return whether `this.expression` is a nested series of unbracketed
    // list expressions that ends in the unquoted string `!important` (or an
    // unquoted string ending in " !important", which can occur if `value` is
    // set manually).
    throw new Error('Not yet implemented');
  }
  set important(value: boolean) {
    // TODO: If value !== this.important, either set this to a space-separated
    // list whose second value is `!important` or remove the existing
    // `!important` from wherever it's defined. Or if that's too complex, just
    // bake this to a string expression and edit that.
    throw new Error('Not yet implemented');
  }

  get variable(): boolean {
    const first = this.propInterpolation.nodes[0];
    return typeof first === 'string' && first.startsWith('--');
  }

  /**
   * Iterators that are currently active within this declaration's children.
   * Their indices refer to the last position that has already been sent to the
   * callback, and are updated when {@link _nodes} is modified.
   */
  readonly #iterators: Array<{index: number}> = [];

  constructor(defaults: DeclarationProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.Declaration);
  constructor(defaults?: DeclarationProps, inner?: sassInternal.Declaration) {
    super(defaults as unknown as postcss.DeclarationProps);
    this.raws ??= {};

    if (inner) {
      this.source = new LazySource(inner);
      this.propInterpolation = new Interpolation(undefined, inner.name);
      if (inner.value) {
        this.expression = convertExpression(inner.value);
      }
      appendInternalChildren(this, inner.children);
    }
  }

  append(...children: NewNode[]): this {
    this.nodes ??= [];
    return super.append(...children);
  }

  prepend(...children: NewNode[]): this {
    this.nodes ??= [];
    return super.prepend(...children);
  }

  clone(overrides?: Partial<DeclarationProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      [
        'raws',
        'propInterpolation',
        {name: 'expression', explicitUndefined: true},
      ],
      ['prop', 'value'],
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['prop', 'value', 'propInterpolation', 'expression', 'nodes'],
      inputs,
    );
  }

  /** @hidden */
  toString(
    stringifier: postcss.Stringifier | postcss.Syntax = sassParser.scss
      .stringify,
  ): string {
    return super.toString(stringifier);
  }

  /** @hidden */
  get nonStatementChildren(): ReadonlyArray<Interpolation | AnyExpression> {
    const result: Array<Interpolation | AnyExpression> = [
      this.propInterpolation,
    ];
    if (this.expression) result.push(this.expression);
    return result;
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    // Casting to `any` is necessary because `_Declaration` can't extend
    // `ContainerWithChildren` because it is a union type.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return normalize(this as any, node, sample);
  }
}
