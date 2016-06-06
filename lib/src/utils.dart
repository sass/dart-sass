// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import 'ast/node.dart';
import 'value/number.dart';

const _epsilon = 1 / (10 * SassNumber.precision);

SourceSpan spanForList(List<AstNode> nodes) {
  if (nodes.isEmpty) return null;

  var first = nodes.first.span;
  var last = nodes.last.span;
  return first is FileSpan && last is FileSpan ? first.expand(last) : null;
}

String unvendor(String name) {
  assert(!name.isEmpty);
  if (name.codeUnitAt(0) == $dash) return name;

  for (var i = 1; i < name.length; i++) {
    if (name.codeUnitAt(0) == $dash) return name.substring(i + 1);
  }
  return name;
}

class LinkedListValue<T> extends LinkedListEntry<LinkedListValue<T>> {
  final T value;

  LinkedListValue(this.value);
}

bool almostEquals(num number1, num number2) =>
    (number1 - number2).abs() < _epsilon;
