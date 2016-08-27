// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'expression.dart';
import 'node.dart';

class ArgumentInvocation implements SassNode {
  final List<Expression> positional;

  final Map<String, Expression> named;

  final Expression rest;

  final Expression keywordRest;

  final FileSpan span;

  ArgumentInvocation(Iterable<Expression> positional,
      Map<String, Expression> named, {this.rest, this.keywordRest, this.span})
      : positional = new List.unmodifiable(positional),
        named = new Map.unmodifiable(named) {
    assert(rest != null || keywordRest == null);
  }

  ArgumentInvocation.empty({this.span})
    : positional = const [],
      named = const {},
      rest = null,
      keywordRest = null;

  String toString() {
    var components = new List<Object>.from(positional)
      ..addAll(named.keys.map((name) => "$name: ${named[name]}"));
    if (rest != null) components.add("$rest...");
    if (keywordRest != null) components.add("$keywordRest...");
    return "(${components.join(', ')})";
  }
}
