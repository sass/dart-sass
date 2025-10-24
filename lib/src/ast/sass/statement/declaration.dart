// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../expression/string.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// A declaration (that is, a `name: value` pair).
///
/// {@category AST}
final class Declaration extends ParentStatement {
  /// The name of this declaration.
  final Interpolation name;

  /// The value of this declaration.
  ///
  /// If [children] is `null`, this is never `null`. Otherwise, it may or may
  /// not be `null`.
  final Expression? value;

  final FileSpan span;

  /// Returns whether this declaration's value was parsed as SassScript.
  ///
  /// This is `false` for custom properties as well as the `result` property of
  /// the plain CSS `@function` rule.
  ///
  /// Note that this can return `true` for declarations that will ultimately be
  /// serialized as custom properties if they aren't *parsed as* custom
  /// properties, such as `#{--foo}: ...`.
  ///
  /// If this is `false`, then `value` will be an unquoted [StringExpression].
  ///
  /// @nodoc
  @internal
  final bool parsedAsSassScript;

  /// Creates a declaration with no children.
  Declaration(this.name, this.value, this.span)
      : parsedAsSassScript = true,
        super(null);

  /// Creates a declaration with no children whose value is not parsed as
  /// SassScript.
  Declaration.notSassScript(this.name, StringExpression this.value, this.span)
      : parsedAsSassScript = false,
        super(null);

  /// Creates a declaration with children.
  ///
  /// For these declarations, a value is optional.
  Declaration.nested(
    this.name,
    Iterable<Statement> children,
    this.span, {
    this.value,
  })  : parsedAsSassScript = true,
        super(List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitDeclaration(this);

  String toString() {
    var buffer = StringBuffer();
    buffer.write(name);
    buffer.writeCharCode($colon);

    if (value != null) {
      if (parsedAsSassScript) buffer.writeCharCode($space);
      buffer.write("$value");
    }

    if (children case var children?) {
      return "$buffer {${children.join(" ")}}";
    } else {
      return "$buffer;";
    }
  }
}
