// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../node.dart';

/// A value in a plain CSS tree.
///
/// This is used to associate a span with a value that doesn't otherwise track
/// its span.
class CssValue<T> implements AstNode {
  /// The value.
  T value;

  /// The span associated with the value.
  final FileSpan span;

  CssValue(this.value, this.span);

  String toString() => value.toString();
}
