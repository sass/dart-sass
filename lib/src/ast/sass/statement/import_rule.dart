// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression/string.dart';
import '../statement.dart';

/// An `@import` rule that will import a Sass file at runtime.
class ImportRule implements Statement {
  /// The URI of the file to import.
  ///
  /// If this is relative, it's relative to the containing file.
  final Uri url;

  final FileSpan span;

  ImportRule(this.url, this.span);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitImportRule(this);

  String toString() => "@import ${StringExpression.quoteText(url.toString())};";
}
