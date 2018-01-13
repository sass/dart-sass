// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/value.dart';
import '../value.dart';
import 'external/value.dart' as ext;

/// The SassScript `true` value.
const sassTrue = const SassBoolean._(true);

/// The SassScript `false` value.
const sassFalse = const SassBoolean._(false);

class SassBoolean extends Value implements ext.SassBoolean {
  final bool value;

  bool get isTruthy => value;

  factory SassBoolean(bool value) => value ? sassTrue : sassFalse;

  const SassBoolean._(this.value);

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitBoolean(this);

  SassBoolean assertBoolean([String name]) => this;

  Value unaryNot() => value ? sassFalse : sassTrue;
}
