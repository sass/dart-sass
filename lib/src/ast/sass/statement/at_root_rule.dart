// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// An `@at-root` rule.
///
/// This moves it contents "up" the tree through parent nodes.
class AtRootRule extends ParentStatement {
  /// The query specifying which statements this should move its contents
  /// through.
  final Interpolation query;

  final FileSpan span;

  AtRootRule(Iterable<Statement/*!*/> children, this.span, {this.query})
      : super(List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitAtRootRule(this);

  String toString() {
    var buffer = StringBuffer("@at-root ");
    if (query != null) buffer.write("$query ");
    return "$buffer {${children.join(' ')}}";
  }
}
