// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../import.dart';
import '../statement.dart';

/// An `@import` rule.
///
/// {@category AST}
final class ImportRule extends Statement {
  /// The imports imported by this statement.
  final List<Import> imports;

  final FileSpan span;

  /// @nodoc
  @internal
  final FileLocation afterTrailing;

  ImportRule(Iterable<Import> imports, this.span)
      : imports = List.unmodifiable(imports),
        afterTrailing = span.end;

  /// @nodoc
  @internal
  ImportRule.internal(Iterable<Import> imports, this.span, this.afterTrailing)
      : imports = List.unmodifiable(imports);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitImportRule(this);

  String toString() => "@import ${imports.join(', ')};";
}
