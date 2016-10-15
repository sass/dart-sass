// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/value.dart';
import '../value.dart';

/// The SassScript `true` value.
const sassTrue = const SassBoolean._(true);

/// The SassScript `false` value.
const sassFalse = const SassBoolean._(false);

/// A SassScript boolean value.
class SassBoolean extends Value {
  /// Whether this value is `true` or `false`.
  final bool value;

  bool get isTruthy => value;

  /// Returns a [SassBoolean] corresponding to [value].
  ///
  /// This just returns [sassTrue] or [sassFalse]; it doesn't allocate a new
  /// value.
  factory SassBoolean(bool value) => value ? sassTrue : sassFalse;

  const SassBoolean._(this.value);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitBoolean(this);

  SassBoolean assertBoolean([String name]) => this;

  Value or(Value other) => value ? this : other;

  Value and(Value other) => value ? other : this;

  Value unaryNot() => value ? sassFalse : sassTrue;
}
