// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../visitor.dart';

abstract class AstNode {
  SourceSpan get span;

  /*=T*/ visit/*<T>*/(AstVisitor/*<T>*/ visitor);
}