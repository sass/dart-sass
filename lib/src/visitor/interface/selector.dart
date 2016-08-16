// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/selector.dart';

abstract class SelectorVisitor<T> {
  T visitAttributeSelector(AttributeSelector attribute) => null;
  T visitClassSelector(ClassSelector klass) => null;
  T visitIDSelector(IDSelector id) => null;
  T visitParentSelector(ParentSelector placeholder) => null;
  T visitPlaceholderSelector(PlaceholderSelector placeholder) => null;
  T visitTypeSelector(TypeSelector type) => null;
  T visitUniversalSelector(UniversalSelector universal) => null;

  T visitComplexSelector(ComplexSelector complex) {
    for (var component in complex.components) {
      if (component is CompoundSelector) component.accept(this);
    }
    return null;
  }

  T visitCompoundSelector(CompoundSelector compound) {
    for (var simple in compound.components) {
      simple.accept(this);
    }
    return null;
  }

  T visitSelectorList(SelectorList list) {
    for (var complex in list.components) {
      complex.accept(this);
    }
    return null;
  }

  T visitPseudoSelector(PseudoSelector pseudo) {
    if (pseudo.selector != null) visitSelectorList(pseudo.selector);
    return null;
  }
}
