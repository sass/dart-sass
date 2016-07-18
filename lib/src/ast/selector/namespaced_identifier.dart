// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

class NamespacedIdentifier {
  final String name;

  final String namespace;

  NamespacedIdentifier(this.name, {this.namespace});

  bool operator==(other) => other is NamespacedIdentifier &&
      other.name == name && other.namespace == namespace;

  int get hashCode => name.hashCode ^ namespace.hashCode;

  String toString() => namespace == null ? name : "$namespace|$name";
}
