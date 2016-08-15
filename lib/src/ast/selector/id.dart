// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../../visitor/interface/selector.dart';
import '../selector.dart';

class IDSelector extends SimpleSelector {
  final String name;

  int get minSpecificity => math.pow(super.minSpecificity, 2);

  IDSelector(this.name);

  /*=T*/ accept/*<T>*/(SelectorVisitor/*<T>*/ visitor) =>
      visitor.visitIDSelector(this);

  List<SimpleSelector> unify(List<SimpleSelector> compound) {
    // A given compound selector may only contain one ID.
    if (compound.any((simple) => simple is IDSelector && simple != this)) {
      return null;
    }

    return super.unify(compound);
  }

  bool operator==(other) => other is ClassSelector && other.name == name;

  int get hashCode => name.hashCode;

  String toString() => "#$name";
}
