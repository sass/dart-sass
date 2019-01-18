// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression/string.dart';
import '../statement.dart';

/// A `@use` rule.
class UseRule implements Statement {
  /// The URI of the module to use.
  ///
  /// If this is relative, it's relative to the containing file.
  final Uri url;

  /// The namespace for members of the used module, or `null` if the members
  /// can be accessed without a namespace.
  final String namespace;

  final FileSpan span;

  UseRule(this.url, this.namespace, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitUseRule(this);

  String toString() => "@use ${StringExpression.quoteText(url.toString())} as "
      "${namespace ?? "*"};";
}
