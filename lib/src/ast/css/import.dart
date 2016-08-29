// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';

class CssImport extends CssNode {
  final Uri url;

  final FileSpan span;

  CssImport(this.url, this.span);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) => visitor.visitImport(this);
}
