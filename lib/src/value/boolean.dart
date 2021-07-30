// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../visitor/interface/value.dart';
import '../value.dart';

/// The SassScript `true` value.
///
/// {@category Value}
const sassTrue = SassBoolean._(true);

/// The SassScript `false` value.
///
/// {@category Value}
const sassFalse = SassBoolean._(false);

/// A SassScript boolean value.
///
/// {@category Value}
@sealed
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

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitBoolean(this);

  SassBoolean assertBoolean([String? name]) => this;

  /// @nodoc
  @internal
  Value unaryNot() => value ? sassFalse : sassTrue;
}
