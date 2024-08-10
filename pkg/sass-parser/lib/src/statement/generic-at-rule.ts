import * as postcss from 'postcss';
import type {AtRuleRaws as PostcssAtRuleRaws} from 'postcss/lib/at-rule';

import {Interpolation} from '../interpolation';
import {LazySource} from '../lazy-source';
import type * as sassInternal from '../sass-internal';
import * as utils from '../utils';
import {
  AtRule,
  ChildNode,
  ContainerProps,
  NewNode,
  Statement,
  StatementWithChildren,
  appendInternalChildren,
  normalize,
} from '.';
import {_AtRule} from './at-rule-internal';
import {interceptIsClean} from './intercept-is-clean';
import * as sassParser from '../..';

/**
 * The set of raws supported by {@link GenericAtRule}.
 *
 * Sass doesn't support PostCSS's `params` raws, since the param interpolation
 * is lexed and made directly available to the caller.
 *
 * @category Statement
 */
export type GenericAtRuleRaws = Omit<PostcssAtRuleRaws, 'params'>;

/**
 * The initializer properties for {@link GenericAtRule}.
 *
 * @category Statement
 */
export type GenericAtRuleProps = ContainerProps & {
  raws?: GenericAtRuleRaws;
} & (
    | {nameInterpolation: Interpolation | string; name?: never}
    | {name: string; nameInterpolation?: never}
  ) &
  (
    | {paramsInterpolation?: Interpolation | string; params?: never}
    | {params?: string | number; paramsInterpolation?: never}
  );

/**
 * An `@`-rule that isn't parsed as a more specific type. Extends
 * [`postcss.AtRule`].
 *
 * [`postcss.AtRule`]: https://postcss.org/api/#atrule
 *
 * @category Statement
 */
export class GenericAtRule
  extends _AtRule<Partial<GenericAtRuleProps>>
  implements Statement
{
  readonly sassType = 'atrule' as const;
  declare parent: StatementWithChildren | undefined;
  declare raws: GenericAtRuleRaws;

  get name(): string {
    return this.nameInterpolation.toString();
  }
  set name(value: string) {
    this.nameInterpolation = value;
  }

  /**
   * The interpolation that represents this at-rule's name.
   */
  get nameInterpolation(): Interpolation {
    return this._nameInterpolation!;
  }
  set nameInterpolation(nameInterpolation: Interpolation | string) {
    if (this._nameInterpolation) this._nameInterpolation.parent = undefined;
    if (typeof nameInterpolation === 'string') {
      nameInterpolation = new Interpolation({nodes: [nameInterpolation]});
    }
    nameInterpolation.parent = this;
    this._nameInterpolation = nameInterpolation;
  }
  private _nameInterpolation?: Interpolation;

  get params(): string {
    return this.paramsInterpolation?.toString() ?? '';
  }
  set params(value: string | number | undefined) {
    this.paramsInterpolation = value === '' ? undefined : value?.toString();
  }

  /**
   * The interpolation that represents this at-rule's parameters, or undefined
   * if it has no parameters.
   */
  get paramsInterpolation(): Interpolation | undefined {
    return this._paramsInterpolation;
  }
  set paramsInterpolation(
    paramsInterpolation: Interpolation | string | undefined
  ) {
    if (this._paramsInterpolation) this._paramsInterpolation.parent = undefined;
    if (typeof paramsInterpolation === 'string') {
      paramsInterpolation = new Interpolation({nodes: [paramsInterpolation]});
    }
    if (paramsInterpolation) paramsInterpolation.parent = this;
    this._paramsInterpolation = paramsInterpolation;
  }
  private _paramsInterpolation: Interpolation | undefined;

  constructor(defaults: GenericAtRuleProps);
  /** @hidden */
  constructor(_: undefined, inner: sassInternal.AtRule);
  constructor(defaults?: GenericAtRuleProps, inner?: sassInternal.AtRule) {
    super(defaults as postcss.AtRuleProps);

    if (inner) {
      this.source = new LazySource(inner);
      this.nameInterpolation = new Interpolation(undefined, inner.name);
      if (inner.value) {
        this.paramsInterpolation = new Interpolation(undefined, inner.value);
      }
      appendInternalChildren(this, inner.children);
    }
  }

  clone(overrides?: Partial<GenericAtRuleProps>): this {
    return utils.cloneNode(
      this,
      overrides,
      [
        'nodes',
        'raws',
        'nameInterpolation',
        {name: 'paramsInterpolation', explicitUndefined: true},
      ],
      ['name', {name: 'params', explicitUndefined: true}]
    );
  }

  toJSON(): object;
  /** @hidden */
  toJSON(_: string, inputs: Map<postcss.Input, number>): object;
  toJSON(_?: string, inputs?: Map<postcss.Input, number>): object {
    return utils.toJSON(
      this,
      ['name', 'nameInterpolation', 'params', 'paramsInterpolation', 'nodes'],
      inputs
    );
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
    const result = [this.nameInterpolation];
    if (this.paramsInterpolation) result.push(this.paramsInterpolation);
    return result;
  }

  /** @hidden */
  normalize(node: NewNode, sample?: postcss.Node): ChildNode[] {
    return normalize(this, node, sample);
  }
}

interceptIsClean(GenericAtRule);
