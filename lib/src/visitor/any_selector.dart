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
  @override
  bool visitComplexSelector(ComplexSelector complex) => complex.components.any(
        (component) => visitCompoundSelector(component.selector),
      );

  @override
  bool visitCompoundSelector(CompoundSelector compound) =>
      compound.components.any((simple) => simple.accept(this));

  @override
  bool visitPseudoSelector(PseudoSelector pseudo) {
    var selector = pseudo.selector;
    return selector == null ? false : selector.accept(this);
  }

  @override
  bool visitSelectorList(SelectorList list) =>
      list.components.any(visitComplexSelector);

  @override
  bool visitAttributeSelector(AttributeSelector attribute) => false;

  @override
  bool visitClassSelector(ClassSelector klass) => false;

  @override
  bool visitIDSelector(IDSelector id) => false;

  @override
  bool visitParentSelector(ParentSelector parent) => false;

  @override
  bool visitPlaceholderSelector(PlaceholderSelector placeholder) => false;

  @override
  bool visitTypeSelector(TypeSelector type) => false;

  @override
  bool visitUniversalSelector(UniversalSelector universal) => false;
}
