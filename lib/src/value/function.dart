// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../callable.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript function reference.
///
/// A function reference captures a function from the local environment so that
/// it may be passed between modules.
class SassFunction extends Value {
  /// The callable that this function invokes.
  final Callable callable;

  SassFunction(this.callable);

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitFunction(this);

  SassFunction assertFunction([String name]) => this;

  bool operator ==(other) =>
      other is SassFunction && callable == other.callable;

  int get hashCode => callable.hashCode;
}
