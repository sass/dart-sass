// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../exception.dart';
import '../../../parse/scss.dart';
import '../../../utils.dart';
import '../../../util/span.dart';
import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../declaration.dart';
import '../statement.dart';
import 'silent_comment.dart';

/// A variable declaration.
///
/// This defines or sets a variable.
///
/// {@category AST}
final class VariableDeclaration extends Statement implements SassDeclaration {
  /// The namespace of the variable being set, or `null` if it's defined or set
  /// without a namespace.
  final String? namespace;

  /// The name of the variable, with underscores converted to hyphens.
  final String name;

  /// The comment immediately preceding this declaration.
  SilentComment? comment;

  /// The value the variable is being assigned to.
  final Expression expression;

  /// Whether this is a guarded assignment.
  ///
  /// Guarded assignments only happen if the variable is undefined or `null`.
  final bool isGuarded;

  /// Whether this is a global assignment.
  ///
  /// Global assignments always affect only the global scope.
  final bool isGlobal;

  final FileSpan span;

  /// The variable name as written in the document, without underscores
  /// converted to hyphens and including the leading `$`.
  ///
  /// This isn't particularly efficient, and should only be used for error
  /// messages.
  String get originalName => declarationName(span);

  FileSpan get nameSpan {
    var span = this.span;
    if (namespace != null) span = span.withoutNamespace();
    return span.initialIdentifier(includeLeading: 1);
  }

  FileSpan? get namespaceSpan =>
      namespace == null ? null : span.initialIdentifier();

  VariableDeclaration(this.name, this.expression, this.span,
      {this.namespace, bool guarded = false, bool global = false, this.comment})
      : isGuarded = guarded,
        isGlobal = global {
    if (namespace != null && global) {
      throw ArgumentError(
          "Other modules' members can't be defined with !global.");
    }
  }

  /// Parses a variable declaration from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  ///
  /// @nodoc
  @internal
  factory VariableDeclaration.parse(String contents, {Object? url}) =>
      ScssParser(contents, url: url).parseVariableDeclaration();

  T accept<T>(StatementVisitor<T> visitor) =>
      visitor.visitVariableDeclaration(this);

  String toString() {
    var buffer = StringBuffer();
    if (namespace != null) buffer.write("$namespace.");
    buffer.write("\$$name: $expression;");
    return buffer.toString();
  }
}
