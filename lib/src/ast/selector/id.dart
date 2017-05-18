// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// An ID selector.
///
/// This selects elements whose `id` attribute exactly matches the given name.
class IDSelector extends SimpleSelector {
  /// The ID name this selects for.
  final String name;

  int get minSpecificity => math.pow(super.minSpecificity, 2) as int;

  IDSelector(this.name);

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitIDSelector(this);

  IDSelector addSuffix(String suffix) => new IDSelector(name + suffix);

  List<SimpleSelector> unify(List<SimpleSelector> compound) {
    // A given compound selector may only contain one ID.
    if (compound.any((simple) => simple is IDSelector && simple != this)) {
      return null;
    }

    return super.unify(compound);
  }

  bool operator ==(other) => other is IDSelector && other.name == name;

  int get hashCode => name.hashCode;
}
