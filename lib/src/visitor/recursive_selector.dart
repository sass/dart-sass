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
  @override
  void visitAttributeSelector(AttributeSelector attribute) {}

  @override
  void visitClassSelector(ClassSelector klass) {}

  @override
  void visitIDSelector(IDSelector id) {}

  @override
  void visitParentSelector(ParentSelector placeholder) {}

  @override
  void visitPlaceholderSelector(PlaceholderSelector placeholder) {}

  @override
  void visitTypeSelector(TypeSelector type) {}

  @override
  void visitUniversalSelector(UniversalSelector universal) {}

  @override
  void visitComplexSelector(ComplexSelector complex) {
    for (var component in complex.components) {
      visitCompoundSelector(component.selector);
    }
  }

  @override
  void visitCompoundSelector(CompoundSelector compound) {
    for (var simple in compound.components) {
      simple.accept(this);
    }
  }

  @override
  void visitPseudoSelector(PseudoSelector pseudo) =>
      pseudo.selector.andThen(visitSelectorList);

  @override
  void visitSelectorList(SelectorList list) {
    for (var complex in list.components) {
      visitComplexSelector(complex);
    }
  }
}
