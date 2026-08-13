// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../import.dart';
import '../statement.dart';

/// An `@import` rule.
///
/// {@category AST}
final class ImportRule(Iterable<Import> imports, @override final FileSpan span)
    extends Statement {
  /// The imports imported by this statement.
  final List<Import> imports = List.unmodifiable(imports);

  @override
  T accept<T>(StatementVisitor<T> visitor) => visitor.visitImportRule(this);

  @override
  String toString() => "@import ${imports.join(', ')};";
}
