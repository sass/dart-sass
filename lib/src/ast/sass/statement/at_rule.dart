// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// An unknown at-rule.
///
/// {@category AST}
final class AtRule(
  /// The name of this rule.
  final Interpolation name,
  @override final FileSpan span, {

  /// The value of this rule.
  final Interpolation? value,
  Iterable<Statement>? children,
}) extends ParentStatement {
  this : super(children == null ? null : List.unmodifiable(children));

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitAtRule(this);

  @override
  String toString() {
    var buffer = StringBuffer("@$name");
    if (value != null) buffer.write(" $value");

    var children = this.children;
    return children == null ? "$buffer;" : "$buffer {${children.join(" ")}}";
  }
}
