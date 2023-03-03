// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../extend/functions.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A type selector.
///
/// This selects elements whose name equals the given name.
///
/// {@category AST}
@sealed
class TypeSelector extends SimpleSelector {
  /// The element name being selected.
  final QualifiedName name;

  int get specificity => 1;

  TypeSelector(this.name, FileSpan span) : super(span);

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitTypeSelector(this);

  /// @nodoc
  @internal
  TypeSelector addSuffix(String suffix) => TypeSelector(
      QualifiedName(name.name + suffix, namespace: name.namespace), span);

  /// @nodoc
  @internal
  List<SimpleSelector>? unify(List<SimpleSelector> compound) {
    if (compound.first is UniversalSelector || compound.first is TypeSelector) {
      var unified = unifyUniversalAndElement(this, compound.first);
      if (unified == null) return null;
      return [unified, ...compound.skip(1)];
    } else {
      return [this, ...compound];
    }
  }

  bool isSuperselector(SimpleSelector other) =>
      super.isSuperselector(other) ||
      (other is TypeSelector &&
          name.name == other.name.name &&
          (name.namespace == '*' || name.namespace == other.name.namespace));

  bool operator ==(Object other) => other is TypeSelector && other.name == name;

  int get hashCode => name.hashCode;
}
