// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import 'ast/node.dart';
import 'ast/selector.dart';
import 'value/number.dart';

const _epsilon = 1 / (10 * SassNumber.precision);

class LinkedListValue<T> extends LinkedListEntry<LinkedListValue<T>> {
  final T value;

  LinkedListValue(this.value);
}

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

SimpleSelector unifyUniversalAndElement(SimpleSelector selector1,
    SimpleSelector selector2) {
  String namespace1;
  String name1;
  if (selector1 is UniversalSelector) {
    namespace1 = selector1.namespace;
  } else if (selector1 is TypeSelector) {
    namespace1 = selector1.name.namespace;
    name1 = selector1.name.name;
  } else {
    throw new ArgumentError.value(
        selector1,
        'selector1',
        'must be a UniversalSelector or a TypeSelector');
  }

  String namespace2;
  String name2;
  if (selector2 is UniversalSelector) {
    namespace2 = selector2.namespace;
  } else if (selector2 is TypeSelector) {
    namespace2 = selector2.name.namespace;
    name2 = selector2.name.name;
  } else {
    throw new ArgumentError.value(
        selector2,
        'selector2',
        'must be a UniversalSelector or a TypeSelector');
  }

  String namespace;
  if (namespace1 == namespace2 || namespace2 == null || namespace2 == '*') {
    namespace = namespace1;
  } else if (namespace1 == null || namespace1 == '*') {
    namespace = namespace2;
  } else {
    return null;
  }

  String namespace;
  if (name1 == name2 || name2 == null) {
    namespace = name1;
  } else if (name1 == null || name1 == '*') {
    namespace = name2;
  } else {
    return null;
  }

  return name == null
      ? new UniversalSelector(namespace: namespace)
      : new TypeSelector(
                new NamespacedIdentifier(name, namespace: namespace));
}
