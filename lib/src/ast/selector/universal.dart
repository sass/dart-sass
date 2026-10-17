// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../extend/functions.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// Matches any element in the given namespace.
///
/// {@category AST}
final class UniversalSelector(super.span, {SelectorNamespace? namespace})
    extends SimpleSelector {
  /// The namespace.
  ///
  /// This defaults to [SelectorNamespace.defaultNamespace].
  final SelectorNamespace namespace = namespace ?? .defaultNamespace;

  @override
  int get specificity => 0;

  @override
  T accept<T>(SelectorVisitor<T> visitor) =>
      visitor.visitUniversalSelector(this);

  /// @nodoc
  @override
  @internal
  List<SimpleSelector>? unify(List<SimpleSelector> compound) {
    switch (compound) {
      case [UniversalSelector() || TypeSelector(), ...var rest]:
        var unified = unifyUniversalAndElement(this, compound.first);
        if (unified == null) return null;
        return [unified, ...rest];

      case [PseudoSelector first] when first.isHost || first.isHostContext:
        return null;

      case []:
        return [this];

      case _:
        return switch (namespace) {
          .defaultNamespace || .any => compound,
          _ => [this, ...compound],
        };
    }
  }

  @override
  bool isSuperselector(SimpleSelector other) {
    if (namespace == .any) return true;
    if (other is TypeSelector) return namespace == other.name.namespace;
    if (other is UniversalSelector) return namespace == other.namespace;
    return namespace == .defaultNamespace || super.isSuperselector(other);
  }

  @override
  bool operator ==(Object other) =>
      other is UniversalSelector && other.namespace == namespace;

  @override
  int get hashCode => namespace.hashCode;
}
