// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

/// A [qualified name].
///
/// [qualified name]: https://www.w3.org/TR/css3-namespace/#css-qnames
///
/// {@category AST}
@sealed
class QualifiedName {
  /// The identifier name.
  final String name;

  /// The namespace name.
  ///
  /// If this is `null`, [name] belongs to the default namespace. If it's the
  /// empty string, [name] belongs to no namespace. If it's `*`, [name] belongs
  /// to any namespace. Otherwise, [name] belongs to the given namespace.
  final String? namespace;

  QualifiedName(this.name, {this.namespace});

  bool operator ==(Object other) =>
      other is QualifiedName &&
      other.name == name &&
      other.namespace == namespace;

  int get hashCode => name.hashCode ^ namespace.hashCode;

  String toString() => namespace == null ? name : "$namespace|$name";
}
