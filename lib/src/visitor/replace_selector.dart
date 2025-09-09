// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/selector.dart';
import '../util/nullable.dart';
import 'interface/selector.dart';

/// A visitor that recursively traverses each selector in a selector AST and
/// replaces its contents with the values returned by nested recursion.
///
/// By default, all methods return a copy of the existing selector with its
/// contents recursively replaced.
///
/// In addition to the methods from [SelectorVisitor], this has a
/// [visitSimpleSelector] method which can be used to transform an arbitrary
/// simple selector.
///
/// This avoids creating unnecessary copies. If no children of a given selector
/// are replaced in practice, the original selector object will be returned.
///
/// {@category Visitor}
mixin ReplaceSelectorVisitor implements SelectorVisitor<Selector> {
  SimpleSelector visitAttributeSelector(AttributeSelector attribute) =>
      attribute;
  SimpleSelector visitClassSelector(ClassSelector klass) => klass;
  SimpleSelector visitIDSelector(IDSelector id) => id;
  SimpleSelector visitParentSelector(ParentSelector parent) => parent;
  SimpleSelector visitPlaceholderSelector(PlaceholderSelector placeholder) =>
      placeholder;
  SimpleSelector visitTypeSelector(TypeSelector type) => type;
  SimpleSelector visitUniversalSelector(UniversalSelector universal) =>
      universal;
  SimpleSelector visitSimpleSelector(SimpleSelector selector) =>
      selector.accept(this) as SimpleSelector;

  SelectorList visitSelectorList(SelectorList list) =>
      switch (_visitComponents(list.components, visitComplexSelector)) {
        var components? => SelectorList(components, list.span),
        _ => list,
      };

  ComplexSelector visitComplexSelector(ComplexSelector complex) =>
      switch (_visitComponents(
          complex.components, _visitComplexSelectorComponent)) {
        var components? => ComplexSelector(components, complex.span,
            leadingCombinator: complex.leadingCombinator,
            lineBreak: complex.lineBreak),
        _ => complex,
      };

  ComplexSelectorComponent _visitComplexSelectorComponent(
          ComplexSelectorComponent component) =>
      switch (visitCompoundSelector(component.selector)) {
        var result when identical(component.selector, result) => component,
        var result => ComplexSelectorComponent(result, component.span,
            combinator: component.combinator),
      };

  CompoundSelector visitCompoundSelector(CompoundSelector compound) =>
      switch (_visitComponents(compound.components, visitSimpleSelector)) {
        var components? => CompoundSelector(components, compound.span),
        _ => compound,
      };

  SimpleSelector visitPseudoSelector(PseudoSelector pseudo) =>
      switch (pseudo.selector.andThen(visitSelectorList)) {
        var selector? => PseudoSelector(pseudo.name, pseudo.span,
            element: pseudo.isElement,
            argument: pseudo.argument,
            selector: selector),
        _ => pseudo,
      };

  /// Returns the result of passing each of [components] through [visit], unless
  /// all of these calls return the original components in which case this
  /// returns `null`.
  ///
  /// This allows the caller to avoid allocations when a selector's subtree is
  /// not transformed in practice.
  List<T>? _visitComponents<T>(List<T> components, T visit(T original)) {
    List<T>? newComponents;
    for (var i = 0; i < components.length; i++) {
      var component = components[i];
      var result = visit(component);
      if (newComponents != null) {
        newComponents.add(result);
      } else if (!identical(component, result)) {
        newComponents = [...components.take(i), result];
      }
    }
    return newComponents;
  }
}
