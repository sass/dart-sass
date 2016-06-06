// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../selector.dart';

class UniversalSelector extends SimpleSelector {
  final String namespace;

  UniversalSelector({this.namespace});

  String toString() => namespace == null ? "*" : "$namespace|*";
}
