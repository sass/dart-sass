// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'node.dart';
import '../../value.dart';

class CssValue<T extends Value> implements CssNode {
  final T value;

  final SourceSpan span;

  CssValue(this.value, {this.span});

  String toString() => value.toString();
}
