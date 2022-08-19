// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../ast/selector.dart';
import 'interface/selector.dart';

/// A visitor that visits each selector in a Sass selector AST and returns
/// `true` if any of the individual methods return `true`.
///
/// Each method returns `false` by default.
@internal
mixin AnySelectorVisitor implements SelectorVisitor<bool> {
  bool visitComplexSelector(ComplexSelector complex) => complex.components
      .any((component) => visitCompoundSelector(component.selector));

  bool visitCompoundSelector(CompoundSelector compound) =>
      compound.components.any((simple) => simple.accept(this));

  bool visitPseudoSelector(PseudoSelector pseudo) {
    var selector = pseudo.selector;
    return selector == null ? false : selector.accept(this);
  }

  bool visitSelectorList(SelectorList list) =>
      list.components.any(visitComplexSelector);

  bool visitAttributeSelector(AttributeSelector attribute) => false;
  bool visitClassSelector(ClassSelector klass) => false;
  bool visitIDSelector(IDSelector id) => false;
  bool visitParentSelector(ParentSelector parent) => false;
  bool visitPlaceholderSelector(PlaceholderSelector placeholder) => false;
  bool visitTypeSelector(TypeSelector type) => false;
  bool visitUniversalSelector(UniversalSelector universal) => false;
}
