// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/selector.dart';

/// An interface for [visitors][] that traverse selectors.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
abstract class SelectorVisitor<T> {
  T visitAttributeSelector(AttributeSelector attribute);
  T visitClassSelector(ClassSelector klass);
  T visitComplexSelector(ComplexSelector complex);
  T visitCompoundSelector(CompoundSelector compound);
  T visitIDSelector(IDSelector id);
  T visitParentSelector(ParentSelector placeholder);
  T visitPlaceholderSelector(PlaceholderSelector placeholder);
  T visitPseudoSelector(PseudoSelector pseudo);
  T visitSelectorList(SelectorList list);
  T visitTypeSelector(TypeSelector type);
  T visitUniversalSelector(UniversalSelector universal);
}
