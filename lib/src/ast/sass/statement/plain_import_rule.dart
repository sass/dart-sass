// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression/string.dart';
import '../statement.dart';

class PlainImportRule implements Statement {
  final Uri url;

  final FileSpan span;

  PlainImportRule(this.url, this.span);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitPlainImportRule(this);

  String toString() => "@import ${StringExpression.quoteText(url.toString())};";
}
