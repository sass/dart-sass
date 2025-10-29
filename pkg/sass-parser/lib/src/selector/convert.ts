// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sassInternal from '../sass-internal';
import {AnySimpleSelector} from '.';
import {AttributeSelector} from './attribute';
import {ClassSelector} from './class';
import {IDSelector} from './id';
import {ParentSelector} from './parent';
import {PlaceholderSelector} from './placeholder';
import {PseudoSelector} from './pseudo';
import {TypeSelector} from './type';
import {UniversalSelector} from './universal';

/** The visitor to use to convert internal Sass nodes to JS. */
const visitor = sassInternal.createSimpleSelectorVisitor<AnySimpleSelector>({
  visitAttributeSelector: inner => new AttributeSelector(undefined, inner),
  visitClassSelector: inner => new ClassSelector(undefined, inner),
  visitIDSelector: inner => new IDSelector(undefined, inner),
  visitParentSelector: inner => new ParentSelector(undefined, inner),
  visitPlaceholderSelector: inner => new PlaceholderSelector(undefined, inner),
  visitPseudoSelector: inner => new PseudoSelector(undefined, inner),
  visitTypeSelector: inner => new TypeSelector(undefined, inner),
  visitUniversalSelector: inner => new UniversalSelector(undefined, inner),
});

/** Converts an internal expression AST node into an external one. */
export function convertSimpleSelector(
  selector: sassInternal.SimpleSelector,
): AnySimpleSelector {
  return selector.accept(visitor);
}
