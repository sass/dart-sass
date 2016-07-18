// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../selector.dart';

class IDSelector extends SimpleSelector {
  final String name;

  IDSelector(this.name);

  bool operator==(other) => other is ClassSelector && other.name == name;

  int get hashCode => name.hashCode;

  String toString() => "#$name";
}
