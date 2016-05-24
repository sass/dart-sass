// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:source_span/source_span.dart';

import 'ast/node.dart';

SourceSpan spanForList(List<AstNode> nodes) {
  if (nodes.isEmpty) return null;

  var first = nodes.first.span;
  var last = nodes.last.span;
  return first is FileSpan && last is FileSpan ? first.expand(last) : null;
}

class LinkedListValue<T> extends LinkedListEntry<LinkedListValue<T>> {
  final T value;

  LinkedListValue(this.value);
}
