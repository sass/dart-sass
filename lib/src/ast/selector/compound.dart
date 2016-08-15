// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../extend/functions.dart';
import '../../utils.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

class CompoundSelector extends Selector implements ComplexSelectorComponent {
  final List<SimpleSelector> components;

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

  CompoundSelector(Iterable<SimpleSelector> components)
      : components = new List.unmodifiable(components);

  /*=T*/ accept/*<T>*/(SelectorVisitor/*<T>*/ visitor) =>
      visitor.visitCompoundSelector(this);

  bool isSuperselector(CompoundSelector other) =>
      compoundIsSuperselector(this, other);

  void _computeSpecificity() {
    _minSpecificity = 0;
    _maxSpecificity = 0;
    for (var simple in components) {
      _minSpecificity += simple.minSpecificity;
      _maxSpecificity += simple.maxSpecificity;
    }
  }

  int get hashCode => listHash(components);

  bool operator ==(other) =>
      other is ComplexSelector && listEquals(components, other.components);
}
