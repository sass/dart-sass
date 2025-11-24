// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {AnySimpleSelector, SimpleSelectorProps} from '.';
import {AttributeSelector} from './attribute';
import {ClassSelector} from './class';
import {IDSelector} from './id';
import {ParentSelector} from './parent';
import {PlaceholderSelector} from './placeholder';
import {PseudoSelector} from './pseudo';
import {TypeSelector} from './type';
import {UniversalSelector} from './universal';

/** Constructs a simple selector from {@link SimpleSelectorProps}. */
export function fromProps(props: SimpleSelectorProps): AnySimpleSelector {
  if ('attribute' in props) return new AttributeSelector(props);
  if ('class' in props) return new ClassSelector(props);
  if ('id' in props) return new IDSelector(props);
  if ('suffix' in props) return new ParentSelector(props);
  if ('placeholder' in props) return new PlaceholderSelector(props);
  if ('pseudo' in props) return new PseudoSelector(props);
  if ('type' in props) return new TypeSelector(props);
  if ('namespace' in props) return new UniversalSelector(props);

  throw new Error(`Unknown node type, keys: ${Object.keys(props)}`);
}
