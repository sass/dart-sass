// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import '../../../value.dart';
import '../../../visitor/interface/modifiable_css.dart';
import '../declaration.dart';
import '../value.dart';
import '../style_rule.dart';
import 'node.dart';

/// A modifiable version of [CssDeclaration] for use in the evaluation step.
final class ModifiableCssDeclaration extends ModifiableCssNode
    implements CssDeclaration {
  final CssValue<String> name;
  final CssValue<Value> value;
  final bool parsedAsCustomProperty;
  final List<CssStyleRule> interleavedRules;
  final Trace? trace;
  final FileSpan valueSpanForMap;
  final FileSpan span;

  bool get isCustomProperty => name.value.startsWith('--');

  /// Returns a new CSS declaration with the given properties.
  ModifiableCssDeclaration(
    this.name,
    this.value,
    this.span, {
    required this.parsedAsCustomProperty,
    Iterable<CssStyleRule>? interleavedRules,
    this.trace,
    FileSpan? valueSpanForMap,
  })  : interleavedRules = interleavedRules == null
            ? const []
            : List.unmodifiable(interleavedRules),
        valueSpanForMap = valueSpanForMap ?? value.span {
    if (parsedAsCustomProperty) {
      if (!isCustomProperty) {
        throw ArgumentError(
          'parsedAsCustomProperty must be false if name doesn\'t begin with '
          '"--".',
        );
      } else if (value.value is! SassString) {
        throw ArgumentError(
          'If parsedAsCustomProperty is true, value must contain a SassString '
          '(was `$value` of type ${value.value.runtimeType}).',
        );
      }
    }
  }

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssDeclaration(this);

  String toString() => "$name: $value;";
}
