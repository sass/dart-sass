// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/selector.dart';
import '../selector.dart';

class ParentSelector extends SimpleSelector {
  final String suffix;

  ParentSelector({this.suffix});

  /*=T*/ accept/*<T>*/(SelectorVisitor/*<T>*/ visitor) =>
      visitor.visitParentSelector(this);

  List<SimpleSelector> unify(List<SimpleSelector> compound) =>
      throw new UnsupportedError("& doesn't support unification.");

  String toString() => "&${suffix ?? ''}";
}
