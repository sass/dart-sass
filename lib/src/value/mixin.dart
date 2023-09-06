// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../callable.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript mixin reference.
///
/// A mixin reference captures a mixin from the local environment so that
/// it may be passed between modules.
///
/// {@category Value}
@sealed
class SassMixin extends Value {
  /// The callable that this mixin invokes.
  ///
  /// Note that this is typed as an [AsyncCallable] so that it will work with
  /// both synchronous and asynchronous evaluate visitors, but in practice the
  /// synchronous evaluate visitor will crash if this isn't a [Callable].
  final AsyncCallable callable;

  SassMixin(this.callable);

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitMixin(this);

  SassMixin assertMixin([String? name]) => this;

  bool operator ==(Object other) =>
      other is SassMixin && callable == other.callable;

  int get hashCode => callable.hashCode;
}
