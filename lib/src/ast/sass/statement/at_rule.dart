// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

/// An unknown at-rule.
class AtRule implements Statement {
  /// The name of this rule.
  final String name;

  /// Like [name], but without any vendor prefixes.
  final String normalizedName;

  /// The value of this rule.
  final Interpolation value;

  /// The children of this rule.
  ///
  /// If [children] is empty, [this] was declared with empty brackets. If
  /// [children] is null, it was declared without brackets.
  final List<Statement> children;

  final FileSpan span;

  AtRule(String name, this.span, {this.value, Iterable<Statement> children})
      : name = name,
        normalizedName = unvendor(name),
        children = children == null ? null : new List.unmodifiable(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitAtRule(this);

  String toString() {
    var buffer = new StringBuffer("@$name");
    if (value != null) buffer.write(" $value");
    return children == null ? "$buffer;" : "$buffer {${children.join(" ")}}";
  }
}
