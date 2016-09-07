// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

class ExtendRule implements Statement {
  final Interpolation selector;

  final bool isOptional;

  final FileSpan span;

  ExtendRule(this.selector, this.span, {bool optional: false})
      : isOptional = optional;

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitExtendRule(this);

  String toString() => "@extend $selector";
}
