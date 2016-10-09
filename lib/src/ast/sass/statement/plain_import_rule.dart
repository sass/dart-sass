// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

/// A rule that produces a plain CSS `@import` rule.
class PlainImportRule implements Statement {
  /// The URL for this import.
  ///
  /// This already contains quotes.
  final Interpolation url;

  final FileSpan span;

  PlainImportRule(this.url, this.span);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitPlainImportRule(this);

  String toString() => "@import $url;";
}
