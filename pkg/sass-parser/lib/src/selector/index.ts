// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Node} from '../node';
import type {AttributeSelector, AttributeSelectorProps} from './attribute';
import type {ClassSelector, ClassSelectorProps} from './class';
import type {IDSelector, IDSelectorProps} from './id';
import type {ParentSelector, ParentSelectorProps} from './parent';
import type {
  PlaceholderSelector,
  PlaceholderSelectorProps,
} from './placeholder';
import type {PseudoSelector, PseudoSelectorProps} from './pseudo';
import type {TypeSelector, TypeSelectorProps} from './type';
import type {UniversalSelector, UniversalSelectorProps} from './universal';

/**
 * The union type of all Sass simple selectors.
 *
 * @category Selector
 */
export type AnySimpleSelector =
  | AttributeSelector
  | ClassSelector
  | IDSelector
  | ParentSelector
  | PlaceholderSelector
  | PseudoSelector
  | TypeSelector
  | UniversalSelector;

/**
 * Sass simple selector types.
 *
 * @category Selector
 */
export type SimpleSelectorType =
  | 'attribute'
  | 'class'
  | 'id'
  | 'parent'
  | 'placeholder'
  | 'pseudo'
  | 'type'
  | 'universal';

/**
 * The union type of all properties that can be used to construct Sass
 * simple selectors.
 *
 * @category Selector
 */
export type SimpleSelectorProps =
  | AttributeSelectorProps
  | ClassSelectorProps
  | IDSelectorProps
  | ParentSelectorProps
  | PlaceholderSelectorProps
  | PseudoSelectorProps
  | TypeSelectorProps
  | UniversalSelectorProps;

/**
 * The superclass of Sass simple selector nodes.
 *
 * @category Selector
 */
export abstract class SimpleSelector extends Node {
  abstract readonly sassType: SimpleSelectorType;
  abstract clone(overrides?: object): this;
}
