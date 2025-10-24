// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../../../value.dart';
import '../../../visitor/interface/modifiable_css.dart';
import '../declaration.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssDeclaration] for use in the evaluation step.
final class ModifiableCssDeclaration extends ModifiableCssNode
    implements CssDeclaration {
  final CssValue<String> name;
  final CssValue<Value> value;
  final bool parsedAsSassScript;
  final Trace? trace;
  final FileSpan valueSpanForMap;
  final FileSpan span;

  bool get isCustomProperty => name.value.startsWith('--');

  /// Returns a new CSS declaration with the given properties.
  ModifiableCssDeclaration(
    this.name,
    this.value,
    this.span, {
    required this.parsedAsSassScript,
    this.trace,
    FileSpan? valueSpanForMap,
  }) : valueSpanForMap = valueSpanForMap ?? value.span {
    if (!parsedAsSassScript) {
      if (value.value is! SassString) {
        throw ArgumentError(
          'If parsedAsSassScript is false, value must contain a SassString '
          '(was `$value` of type ${value.value.runtimeType}).',
        );
      }
    }
  }

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssDeclaration(this);

  String toString() => "$name: $value;";
}
