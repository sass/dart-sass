// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../callable.dart';
import '../visitor/interface/value.dart';
import '../value.dart';
import 'external/value.dart' as internal;

class SassFunction extends Value implements internal.SassFunction {
  final AsyncCallable callable;

  SassFunction(this.callable);

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitFunction(this);

  SassFunction assertFunction([String name]) => this;

  bool operator ==(other) =>
      other is SassFunction && callable == other.callable;

  int get hashCode => callable.hashCode;
}
