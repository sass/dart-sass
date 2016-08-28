// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'media_query.dart';
import 'node.dart';

class CssMediaRule extends CssParentNode {
  final List<CssMediaQuery> queries;

  final FileSpan span;

  CssMediaRule(this.queries, this.span);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitMediaRule(this);

  String toString() => "@media ${queries.join(", ")} {${children.join(" ")}}";
}
