// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/value.dart';
import '../value.dart';

/// The SassScript `null` value.
const sassNull = const SassNull._();

/// A SassScript null value.
///
/// This can't be constructed directly; it can only be accessed via [sassNull].
class SassNull extends Value {
  bool get isTruthy => false;

  bool get isBlank => true;

  const SassNull._();

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitNull(this);

  Value unaryNot() => sassTrue;
}
