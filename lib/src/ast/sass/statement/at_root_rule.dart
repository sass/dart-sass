// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

/// An `@at-root` rule.
///
/// This moves it contents "up" the tree through parent nodes.
class AtRootRule implements Statement {
  /// The query specifying which statements this should move its contents
  /// through.
  final Interpolation query;

  /// The statements contained in [this].
  final List<Statement> children;

  final FileSpan span;

  AtRootRule(Iterable<Statement> children, this.span, {this.query})
      : children = new List.from(children);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitAtRootRule(this);

  String toString() {
    var buffer = new StringBuffer("@at-root ");
    if (query != null) buffer.write("$query ");
    return "$buffer {${children.join(' ')}}";
  }
}
