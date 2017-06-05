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

  final FileSpan span;

  /// Whether this is a custom property declaration, also known as a CSS
  /// variable.
  ///
  /// Custom property declarations always have unquoted [SassString] values.
  bool get isCustomProperty => name.value.startsWith("--");

  CssDeclaration(this.name, this.value, this.span);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitDeclaration(this);
}
