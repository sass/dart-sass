// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../interpolation_buffer.dart';
import '../../../util/span.dart';
import '../expression.dart';
import '../expression/string.dart';
import '../interpolation.dart';
import '../supports_condition.dart';

/// A condition that selects for browsers where a given declaration is
/// supported.
///
/// {@category AST}
final class SupportsDeclaration implements SupportsCondition {
  /// The name of the declaration being tested.
  final Expression name;

  /// The value of the declaration being tested.
  final Expression value;

  final FileSpan span;

  /// Returns whether this is a CSS Custom Property declaration.
  ///
  /// Note that this can return `false` for declarations that will ultimately be
  /// serialized as custom properties if they aren't *parsed as* custom
  /// properties, such as `#{--foo}: ...`.
  ///
  /// If this is `true`, then `value` will be a [StringExpression].
  ///
  /// @nodoc
  @internal
  bool get isCustomProperty => switch (name) {
        StringExpression(hasQuotes: false, :var text) =>
          text.initialPlain.startsWith('--'),
        _ => false
      };

  SupportsDeclaration(this.name, this.value, this.span);

  /// @nodoc
  @internal
  Interpolation toInterpolation() {
    var buffer = InterpolationBuffer();
    buffer.write(span.before(name.span).text);
    if (name case StringExpression(hasQuotes: false, :var text)) {
      buffer.addInterpolation(text);
    } else {
      buffer.add(name, name.span);
    }

    buffer.write(name.span.between(value.span).text);
    if (value.sourceInterpolation case var interpolation?) {
      buffer.addInterpolation(interpolation);
    } else {
      buffer.add(value, value.span);
    }

    buffer.write(span.after(value.span).text);
    return buffer.interpolation(span);
  }

  /// @nodoc
  @internal
  SupportsDeclaration withSpan(FileSpan span) =>
      SupportsDeclaration(name, value, span);

  String toString() => "($name: $value)";
}
