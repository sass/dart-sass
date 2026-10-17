// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../util/string.dart';

/// A [qualified name].
///
/// [qualified name]: https://www.w3.org/TR/css3-namespace/#css-qnames
///
/// {@category AST}
final class QualifiedName(
  /// The identifier name.
  ///
  /// This is the semantic contents of the identifier, with escapes resolved.
  final String name, {
  SelectorNamespace? namespace,
}) {
  /// The namespace.
  ///
  /// This defaults to [SelectorNamespace.defaultNamespace].
  final SelectorNamespace namespace = namespace ?? .defaultNamespace;

  @override
  bool operator ==(Object other) =>
      other is QualifiedName &&
      other.name == name &&
      other.namespace == namespace;

  @override
  int get hashCode => name.hashCode ^ namespace.hashCode;

  @override
  String toString() => switch (namespace) {
    DefaultSelectorNamespace() => name.toCssIdentifier(),
    NoSelectorNamespace() => "|${name.toCssIdentifier()}",
    AnySelectorNamespace() => "*|${name.toCssIdentifier()}",
    NamedSelectorNamespace(name: var namespace) =>
      "${namespace.toCssIdentifier()}|${name.toCssIdentifier()}",
  };
}

/// A namespace for a [qualified name] or a universal selector.
///
/// {@category AST}
sealed class const SelectorNamespace() {
  /// The default namespace for the document.
  ///
  /// For example, `div` has the default namespace.
  static const DefaultSelectorNamespace defaultNamespace =
      DefaultSelectorNamespace._();

  /// Matches any possible namespace.
  ///
  /// For example, `*|div` matches any namespace.
  static const AnySelectorNamespace any = AnySelectorNamespace._();

  /// The default namespace for the document.
  ///
  /// For example, `div` has the default namespace.
  static const NoSelectorNamespace none = NoSelectorNamespace._();

  /// Creates an explicitly-named namespace.
  ///
  /// For example, `foo|div` has the namespace `foo`.
  static NamedSelectorNamespace named(String name) =>
      NamedSelectorNamespace._(name);
}

/// The default namespace for the document.
///
/// For example, `div` has the default namespace.
///
/// {@category AST}
final class const DefaultSelectorNamespace._() extends SelectorNamespace {}

/// Matches any possible namespace.
///
/// For example, `*|div` matches any namespace.
///
/// {@category AST}
final class const AnySelectorNamespace._() extends SelectorNamespace {}

/// The absence of a namespace.
///
/// For example, `|div` has no namespace.
///
/// {@category AST}
final class const NoSelectorNamespace._() extends SelectorNamespace {}

/// A [Namespace] with an explicit name.
///
/// {@category AST}
final class NamedSelectorNamespace._(
  /// The namespace's name.
  ///
  /// This is the semantic contents of the identifier, with escapes resolved.
  final String name,
) extends SelectorNamespace {
  @override
  bool operator ==(Object other) =>
      other is NamedSelectorNamespace && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name.toCssIdentifier();
}
