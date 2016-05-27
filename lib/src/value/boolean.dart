// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/value.dart';
import '../value.dart';

class Boolean extends Value {
  static const sassTrue = const Boolean._(true);
  static const sassFalse = const Boolean._(false);

  final bool value;

  factory Boolean(bool value) => value ? Boolean.sassTrue : Boolean.sassFalse;

  const Boolean._(this.value);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitBoolean(this);

  Value unaryNot() => value ? sassFalse : sassTrue;

  String toString() => value.toString();
}
