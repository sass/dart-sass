// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/selector.dart';
import '../util/nullable.dart';
import 'interface/selector.dart';

/// A visitor that recursively traverses each component of a Selector AST.
///
/// {@category Visitor}
mixin RecursiveSelectorVisitor implements SelectorVisitor<void> {
  void visitAttributeSelector(AttributeSelector attribute) {}
  void visitClassSelector(ClassSelector klass) {}
  void visitIDSelector(IDSelector id) {}
  void visitParentSelector(ParentSelector placeholder) {}
  void visitPlaceholderSelector(PlaceholderSelector placeholder) {}
  void visitTypeSelector(TypeSelector type) {}
  void visitUniversalSelector(UniversalSelector universal) {}

  void visitComplexSelector(ComplexSelector complex) {
    for (var component in complex.components) {
      visitCompoundSelector(component.selector);
    }
  }

  void visitCompoundSelector(CompoundSelector compound) {
    for (var simple in compound.components) {
      simple.accept(this);
    }
  }

  void visitPseudoSelector(PseudoSelector pseudo) =>
      pseudo.selector.andThen(visitSelectorList);

  void visitSelectorList(SelectorList list) {
    for (var complex in list.components) {
      visitComplexSelector(complex);
    }
  }
}
