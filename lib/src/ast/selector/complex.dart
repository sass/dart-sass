// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../extend/functions.dart';
import '../../utils.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

class ComplexSelector extends Selector {
  final List<ComplexSelectorComponent> components;

  // Indices of [components] that are followed by line breaks.
  final List<int> lineBreaks;

  int get minSpecificity {
    if (_minSpecificity == null) _computeSpecificity();
    return _minSpecificity;
  }

  int _minSpecificity;

  int get maxSpecificity {
    if (_maxSpecificity == null) _computeSpecificity();
    return _maxSpecificity;
  }

  int _maxSpecificity;

  bool get containsPlaceholder {
    if (_containsPlaceholder != null) return _containsPlaceholder;
    _containsPlaceholder = components.any((component) =>
        component is CompoundSelector &&
        component.components.any((simple) => simple is PlaceholderSelector));
    return _containsPlaceholder;
  }

  bool _containsPlaceholder;

  ComplexSelector(Iterable<ComplexSelectorComponent> components,
      {Iterable<int> lineBreaks})
      : components = new List.unmodifiable(components),
        lineBreaks =
            lineBreaks == null ? const [] : new List.unmodifiable(lineBreaks);

  /*=T*/ accept/*<T>*/(SelectorVisitor/*<T>*/ visitor) =>
      visitor.visitComplexSelector(this);

  bool isSuperselector(ComplexSelector other) =>
      complexIsSuperselector(components, other.components);

  void _computeSpecificity() {
    _minSpecificity = 0;
    _maxSpecificity = 0;
    for (var component in components) {
      if (component is CompoundSelector) {
        _minSpecificity += component.minSpecificity;
        _maxSpecificity += component.maxSpecificity;
      }
    }
  }

  int get hashCode => listHash(components);

  bool operator ==(other) =>
      other is ComplexSelector && listEquals(components, other.components);
}

abstract class ComplexSelectorComponent {}

class Combinator implements ComplexSelectorComponent {
  static const nextSibling = const Combinator._("+");
  static const child = const Combinator._(">");
  static const followingSibling = const Combinator._("~");

  final String combinator;

  const Combinator._(this.combinator);

  String toString() => combinator;
}
