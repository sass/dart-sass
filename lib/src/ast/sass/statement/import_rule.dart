// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../import.dart';
import '../statement.dart';

/// An `@import` rule.
class ImportRule implements Statement {
  /// The imports imported by this statement.
  List<Import> imports;

  final FileSpan span;

  ImportRule(Iterable<Import> imports, this.span)
      : imports = new List.unmodifiable(imports);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitImportRule(this);

  String toString() => "@import ${imports.join(', ')};";
}
