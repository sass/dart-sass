// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../callable.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript function reference.
///
/// A function reference captures a function from the local environment so that
/// it may be passed between modules.
///
/// {@category Value}
@sealed
class SassFunction extends Value {
  /// The callable that this function invokes.
  ///
  /// Note that this is typed as an [AsyncCallable] so that it will work with
  /// both synchronous and asynchronous evaluate visitors, but in practice the
  /// synchronous evaluate visitor will crash if this isn't a [Callable].
  final AsyncCallable callable;

  SassFunction(this.callable);

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitFunction(this);

  SassFunction assertFunction([String? name]) => this;

  bool operator ==(Object other) =>
      other is SassFunction && callable == other.callable;

  int get hashCode => callable.hashCode;
}
