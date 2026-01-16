// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../value.dart';
import 'node.dart';
import 'value.dart';

/// A plain CSS declaration (that is, a `name: value` pair).
@sealed
abstract interface class CssDeclaration implements CssNode {
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

  /// Whether this property's value was originally parsed as SassScript, as
  /// opposed to a custom property which is parsed as an interpolated sequence
  /// of tokens.
  ///
  /// If this is `false`, [value] will contain an unquoted [SassString].
  /// [isCustomProperty] will *usually* be true, but there are other properties
  /// that may not be parsed as SassScript, like `return` in a plain CSS
  /// `@function`.
  bool get parsedAsSassScript;
}
