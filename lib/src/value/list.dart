// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../utils.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

class SassList extends Value {
  final List<Value> contents;

  final ListSeparator separator;

  final bool isBracketed;

  bool get isBlank => contents.every((element) => element.isBlank);

  SassList(Iterable<Value> contents, this.separator, {bool bracketed: false})
      : contents = new List.unmodifiable(contents),
        isBracketed = bracketed;

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitList(this);

  bool operator ==(other) =>
      other is SassList &&
      other.separator == separator &&
      other.isBracketed == isBracketed &&
      listEquals(other.contents, contents);

  int get hashCode => listHash(contents);

  String toString() {
    var buffer = new StringBuffer();
    if (isBracketed) buffer.writeCharCode($lbracket);
    buffer.write(contents
        .map((element) =>
            _elementNeedsParens(element) ? "($element)" : element.toString())
        .join(separator == ListSeparator.comma ? ", " : " "));
    if (isBracketed) buffer.writeCharCode($rbracket);
    return buffer.toString();
  }

  bool _elementNeedsParens(Value value) {
    if (value is SassList) {
      if (value.contents.length < 2) return false;
      if (value.isBracketed) return false;
      return separator == ListSeparator.comma
          ? separator == ListSeparator.comma
          : separator != ListSeparator.undecided;
    }
    return false;
  }
}

class ListSeparator {
  static const space = const ListSeparator._("space");
  static const comma = const ListSeparator._("comma");
  static const undecided = const ListSeparator._("undecided");

  final String name;

  const ListSeparator._(this.name);

  String toString() => name;
}
