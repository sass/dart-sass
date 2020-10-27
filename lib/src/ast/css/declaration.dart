// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../value.dart';
import '../../visitor/interface/css.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS declaration (that is, a `name: value` pair).
abstract class CssDeclaration extends CssNode {
  /// The name of this declaration.
  CssValue<String> get name;

  /// The value of this declaration.
  CssValue<Value> get value;

  /// The span for [value] that should be emitted to the source map.
  ///
  /// When the declaration's expression is just a variable, this is the span
  /// where that variable was declared whereas [value.span] is the span where
  /// the variable was used. Otherwise, this is identical to [value.span].
  FileSpan get valueSpanForMap;

  /// Returns whether this is a CSS Custom Property declaration.
  bool get isCustomProperty;

  /// Whether this is was originally parsed as a custom property declaration, as
  /// opposed to using something like `#{--foo}: ...` to cause it to be parsed
  /// as a normal Sass declaration.
  ///
  /// If this is `true`, [isCustomProperty] will also be `true` and [value] will
  /// contain a [SassString].
  bool get parsedAsCustomProperty;

  T accept<T>(CssVisitor<T> visitor);
}
