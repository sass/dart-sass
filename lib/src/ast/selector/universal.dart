// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../selector.dart';

class UniversalSelector extends SimpleSelector {
  final String namespace;

  UniversalSelector({this.namespace});

  bool operator==(other) => other is UniversalSelector &&
      other.namespace == namespace;

  int get hashCode => namespace.hashCode;

  String toString() => namespace == null ? "*" : "$namespace|*";
}
