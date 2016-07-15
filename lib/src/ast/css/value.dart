// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../node.dart';

class CssValue<T> implements AstNode {
  final T value;

  final FileSpan span;

  CssValue(this.value, {this.span});

  String toString() => value.toString();
}
