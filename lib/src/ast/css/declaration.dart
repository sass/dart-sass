// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../value.dart';
import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS declaration (that is, a `name: value` pair).
class CssDeclaration extends CssNode {
  /// The name of this declaration.
  final CssValue<String> name;

  /// The value of this declaration.
  final CssValue<Value> value;

  /// The span for [value] that should be emitted to the source map.
  ///
  /// When the declaration's expression is just a variable, this is the span
  /// where that variable was declared whereas [value.span] is the span where
  /// the variable was used. Otherwise, this is identical to [value.span].
  final FileSpan valueSpanForMap;

  final FileSpan span;

  CssDeclaration(this.name, this.value, this.span, {FileSpan valueSpanForMap})
      : valueSpanForMap = valueSpanForMap ?? span;

  T accept<T>(CssVisitor<T> visitor) => visitor.visitDeclaration(this);
}
