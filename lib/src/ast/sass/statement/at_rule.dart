// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// An unknown at-rule.
class AtRule extends ParentStatement {
  /// The name of this rule.
  final Interpolation name;

  /// The value of this rule.
  final Interpolation value;

  final FileSpan span;

  AtRule(this.name, this.span, {this.value, Iterable<Statement/*!*/> children})
      : super(children == null ? null : List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitAtRule(this);

  String toString() {
    var buffer = StringBuffer("@$name");
    if (value != null) buffer.write(" $value");
    return children == null ? "$buffer;" : "$buffer {${children.join(" ")}}";
  }
}
