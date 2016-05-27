// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/sass/statement.dart';
import 'statement.dart';

class Comment implements Statement {
  final String text;

  final bool isSilent;

  final SourceSpan span;

  // TODO: Reformat text.
  Comment(this.text, {bool silent, this.span})
      : isSilent = silent;

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitComment(this);

  String toString() => text;
}