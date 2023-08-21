// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/selector.dart';
import '../util/iterable.dart';
import '../util/nullable.dart';
import 'interface/selector.dart';

/// A [SelectorVisitor] whose `visit*` methods default to returning `null`, but
/// which returns the first non-`null` value returned by any method.
///
/// This can be extended to find the first instance of particular nodes in the
/// AST.
///
/// {@category Visitor}
mixin SelectorSearchVisitor<T> implements SelectorVisitor<T?> {
  T? visitAttributeSelector(AttributeSelector attribute) => null;
  T? visitClassSelector(ClassSelector klass) => null;
  T? visitIDSelector(IDSelector id) => null;
  T? visitParentSelector(ParentSelector placeholder) => null;
  T? visitPlaceholderSelector(PlaceholderSelector placeholder) => null;
  T? visitTypeSelector(TypeSelector type) => null;
  T? visitUniversalSelector(UniversalSelector universal) => null;

  T? visitComplexSelector(ComplexSelector complex) => complex.components
      .search((component) => visitCompoundSelector(component.selector));

  T? visitCompoundSelector(CompoundSelector compound) =>
      compound.components.search((simple) => simple.accept(this));

  T? visitPseudoSelector(PseudoSelector pseudo) =>
      pseudo.selector.andThen(visitSelectorList);

  T? visitSelectorList(SelectorList list) =>
      list.components.search(visitComplexSelector);
}
