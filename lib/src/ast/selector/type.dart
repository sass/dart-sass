// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../selector.dart';

class TypeSelector extends SimpleSelector {
  final NamespacedIdentifier name;

  TypeSelector(this.name);

  bool operator==(other) => other is TypeSelector && other.name == name;

  int get hashCode => name.hashCode;

  String toString() => "$name";
}
