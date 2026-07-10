// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../value.dart';
import '../../../visitor/interface/modifiable_css.dart';
import '../declaration.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssDeclaration] for use in the evaluation step.
final class ModifiableCssDeclaration extends ModifiableCssNode
    implements CssDeclaration {
  @override
  final CssValue<String> name;

  @override
  final CssValue<Value> value;

  @override
  final bool parsedAsSassScript;

  @override
  final FileSpan valueSpanForMap;

  @override
  final FileSpan span;

  @override
  bool get isCustomProperty => name.value.startsWith('--');

  /// Returns a new CSS declaration with the given properties.
  ModifiableCssDeclaration(
    this.name,
    this.value,
    this.span, {
    required this.parsedAsSassScript,
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

  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssDeclaration(this);

  @override
  String toString() => "$name: $value;";
}
