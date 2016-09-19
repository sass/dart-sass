// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/value.dart';
import '../visitor/serialize.dart';
import '../value.dart';

class SassString extends Value {
  final String text;

  SassString(this.text);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitString(this);

  Value plus(Value other) => new SassString(
      text + (other is SassString ? other.text : valueToCss(other)));

  bool operator ==(other) {
    if (other is SassString) return text == other.text;
    if (other is SassIdentifier) return text == other.text;
    return false;
  }

  int get hashCode => text.hashCode;
}
