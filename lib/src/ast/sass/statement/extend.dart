// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';

class Extend implements Statement {
  final Interpolation selector;

  final FileSpan span;

  Extend(this.selector, this.span);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitExtend(this);

  String toString() => "@extend $selector";
}
