// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/src/utils.dart';
import 'package:source_span/source_span.dart';

import '../../util/map.dart';
import 'expression.dart';
import 'expression/list.dart';
import 'node.dart';

/// A set of arguments passed in to a function or mixin.
///
/// {@category AST}
final class ArgumentList implements SassNode {
  /// The arguments passed by position.
  final List<Expression> positional;

  /// The arguments passed by name.
  final Map<String, Expression> named;

  /// The spans for the arguments passed by name, including their argument names.
  ///
  /// This always has the same keys as [named] in the same order.
  final Map<String, FileSpan> namedSpans;

  /// The first rest argument (as in `$args...`).
  final Expression? rest;

  /// The second rest argument, which is expected to only contain a keyword map.
  final Expression? keywordRest;

  @override
  final FileSpan span;

  /// Returns whether this invocation passes no arguments.
  bool get isEmpty => positional.isEmpty && named.isEmpty && rest == null;

  new(
    Iterable<Expression> positional,
    Map<String, Expression> named,
    Map<String, FileSpan> namedSpans,
    this.span, {
    this.rest,
    this.keywordRest,
  }) : positional = List.unmodifiableOf(positional),
       named = Map.unmodifiableOf(named),
       namedSpans = Map.unmodifiableOf(namedSpans) {
    assert(rest != null || keywordRest == null);
    assert(iterableEquals(named.keys, namedSpans.keys));
  }

  /// Creates an invocation that passes no arguments.
  new empty(this.span)
    : positional = const [],
      named = const {},
      namedSpans = const {},
      rest = null,
      keywordRest = null;

  @override
  String toString() {
    var components = [
      for (var argument in positional) _parenthesizeArgument(argument),
      for (var (name, value) in named.pairs)
        "\$$name: ${_parenthesizeArgument(value)}",
      if (rest case var rest?) "${_parenthesizeArgument(rest)}...",
      if (keywordRest case var keywordRest?)
        "${_parenthesizeArgument(keywordRest)}...",
    ];
    return "(${components.join(', ')})";
  }

  /// Wraps [argument] in parentheses if necessary.
  String _parenthesizeArgument(Expression argument) => switch (argument) {
    ListExpression(
      separator: .comma,
      hasBrackets: false,
      contents: [_, _, ...],
    ) =>
      "($argument)",
    _ => argument.toString(),
  };
}
