// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/interface/value.dart';
import '../visitor/serialize.dart';
import '../value.dart';

class SassString extends Value {
  final String text;

  final bool hasQuotes;

  SassString(this.text, {bool quotes: false}) : hasQuotes = quotes;

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitString(this);

  Value plus(Value other) {
    if (other is SassString) {
      return new SassString(text + other.text,
          quotes: hasQuotes || other.hasQuotes);
    } else {
      return new SassString(text + valueToCss(other), quotes: hasQuotes);
    }
  }

  bool operator ==(other) => other is SassString && text == other.text;

  int get hashCode => text.hashCode;
}
