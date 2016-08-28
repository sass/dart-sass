// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';

class CssStylesheet extends CssParentNode {
  final FileSpan span;

  CssStylesheet(this.span);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitStylesheet(this);

  String toString() => children.join(" ");
}
