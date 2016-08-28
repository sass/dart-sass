// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/selector.dart';
import '../selector.dart';

class PlaceholderSelector extends SimpleSelector {
  final String name;

  PlaceholderSelector(this.name);

  /*=T*/ accept/*<T>*/(SelectorVisitor/*<T>*/ visitor) =>
      visitor.visitPlaceholderSelector(this);

  PlaceholderSelector addSuffix(String suffix) =>
      new PlaceholderSelector(name + suffix);

  List<SimpleSelector> unify(List<SimpleSelector> compound) =>
      throw new UnsupportedError("Placeholders don't support unification.");

  bool operator ==(other) => other is PlaceholderSelector && other.name == name;

  int get hashCode => name.hashCode;

  String toString() => "%$name";
}
