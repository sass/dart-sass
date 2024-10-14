// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../../value.dart';
import 'node.dart';
import 'style_rule.dart';
import 'value.dart';

/// A plain CSS declaration (that is, a `name: value` pair).
abstract interface class CssDeclaration implements CssNode {
  /// The name of this declaration.
  CssValue<String> get name;

  /// The value of this declaration.
  CssValue<Value> get value;

  /// A list of style rules that appeared before this declaration in the Sass
  /// input but after it in the CSS output.
  ///
  /// These are used to emit mixed declaration deprecation warnings during
  /// serialization, so we can check based on specificity whether the warnings
  /// are really necessary without worrying about `@extend` potentially changing
  /// things up.
  @internal
  List<CssStyleRule> get interleavedRules;

  /// The stack trace indicating where this node was created.
  ///
  /// This is used to emit interleaved declaration warnings, and is only set if
  /// [interleavedRules] isn't empty.
  Trace? get trace;

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
}
