// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// An ID selector.
///
/// This selects elements whose `id` attribute exactly matches the given name.
///
/// {@category AST}
@sealed
class IDSelector extends SimpleSelector {
  /// The ID name this selects for.
  final String name;

  int get specificity => math.pow(super.specificity, 2) as int;

  IDSelector(this.name, FileSpan span) : super(span);

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitIDSelector(this);

  /// @nodoc
  @internal
  IDSelector addSuffix(String suffix) => IDSelector(name + suffix, span);

  /// @nodoc
  @internal
  List<SimpleSelector>? unify(List<SimpleSelector> compound) {
    // A given compound selector may only contain one ID.
    if (compound.any((simple) => simple is IDSelector && simple != this)) {
      return null;
    }

    return super.unify(compound);
  }

  bool operator ==(Object other) => other is IDSelector && other.name == name;

  int get hashCode => name.hashCode;
}
