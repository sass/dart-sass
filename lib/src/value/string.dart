// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../visitor/interface/value.dart';
import '../visitor/serialize.dart';
import '../value.dart';

class SassString extends Value {
  final String text;

  final bool hasQuotes;

  bool get isCalc {
    if (hasQuotes) return false;
    if (text.length < 6) return false;
    if (text.codeUnitAt(0) != $c && text.codeUnitAt(0) != $C) return false;
    if (text.codeUnitAt(1) != $a && text.codeUnitAt(1) != $A) return false;
    if (text.codeUnitAt(2) != $l && text.codeUnitAt(2) != $L) return false;
    if (text.codeUnitAt(3) != $c && text.codeUnitAt(3) != $C) return false;
    return text.codeUnitAt(4) == $lparen;
  }

  SassString(this.text, {bool quotes: false}) : hasQuotes = quotes;

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitString(this);

  SassString assertString([String name]) => this;

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
