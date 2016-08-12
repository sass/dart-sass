// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';
import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';

import 'ast/node.dart';
import 'ast/selector.dart';
import 'value/number.dart';

const _epsilon = 1 / (10 * SassNumber.precision);

class LinkedListValue<T> extends LinkedListEntry<LinkedListValue<T>> {
  final T value;

  LinkedListValue(this.value);
}

bool listEquals/*<T>*/(List/*<T>*/ list1, List/*<T>*/ list2) =>
    const ListEquality().equals(list1, list2);

FileSpan spanForList(List<AstNode> nodes) {
  if (nodes.isEmpty) return null;
  return nodes.first.span.expand(nodes.last.span);
}

String unvendor(String name) {
  assert(!name.isEmpty);
  if (name.codeUnitAt(0) == $dash) return name;

  for (var i = 1; i < name.length; i++) {
    if (name.codeUnitAt(0) == $dash) return name.substring(i + 1);
  }
  return name;
}

bool equalsIgnoreCase(String string1, String string2) {
  if (string1 == null) return string2 == null;
  if (string2 == null) return false;
  if (string1.length != string2.length) return false;
  return string1.toUpperCase() == string2.toUpperCase();
}

bool almostEquals(num number1, num number2) =>
    (number1 - number2).abs() < _epsilon;

List/*<T>*/ longestCommonSubsequence/*<T>*/(List/*<T>*/ list1,
    List/*<T>*/ list2, {/*=T*/ select(/*=T*/ element1, /*=T*/ element2)}) {
  select ??= (element1, element2) => element1 == element2 ? element1 : null;

  var lengths = new List.generate(
      list1.length + 1, (_) => new List.filled(list2.length + 1, 0),
      growable: false);

  var selections = new List.generate(
      list1.length, (_) => new List/*<T>*/(list2.length),
      growable: false);

  // TODO(nweiz): Calling [select] here may be expensive. Can we use a memoizing
  // approach to avoid calling it O(n*m) times in most cases?
  for (var i = 0; i < list1.length; i++) {
    for (var j = 0; j < list2.length; j++) {
      var selection = select(list1[i], list2[j]);
      selections[i][j] = selection;
      lengths[i + 1][j + 1] = selection == null
          ? math.max(lengths[i + 1][j], lengths[i][j + 1])
          : lengths[i][j] + 1;
    }
  }

  List/*<T>*/ backtrack(int i, int j) {
    if (i == -1 || j == -1) return [];
    var selection = selections[i][j];
    if (selection != null) return backtrack(i - 1, j - 1)..add(selection);

    return lengths[i + 1][j] > lengths[i][j + 1]
        ? backtrack(i, j - 1)
        : backtrack(i - 1, j);
  }

  return backtrack(list1.length - 1, list2.length - 1);
}
