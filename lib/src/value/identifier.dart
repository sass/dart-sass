// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/value.dart';
import '../value.dart';

class SassIdentifier extends Value {
  final String text;

  bool get isBlank => text.isEmpty;

  SassIdentifier(this.text);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitIdentifier(this);

  bool operator ==(other) {
    if (other is SassString) return text == other.text;
    if (other is SassIdentifier) return text == other.text;
    return false;
  }

  int get hashCode => text.hashCode;
}
