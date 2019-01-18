// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../logger.dart';
import '../../../parse/scss.dart';
import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../statement.dart';
import 'silent_comment.dart';

/// A variable declaration.
///
/// This defines or sets a variable.
class VariableDeclaration implements Statement {
  /// The namespace of the variable being set, or `null` if it's defined or set
  /// without a namespace.
  final String namespace;

  /// The name of the variable.
  final String name;

  /// The comment immediatly preceding this declaration.
  SilentComment comment;

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

  VariableDeclaration(this.name, this.expression, this.span,
      {this.namespace,
      bool guarded = false,
      bool global = false,
      SilentComment comment})
      : isGuarded = guarded,
        isGlobal = global,
        comment = comment;

  /// Parses a variable declaration from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory VariableDeclaration.parse(String contents, {url, Logger logger}) =>
      ScssParser(contents, url: url, logger: logger).parseVariableDeclaration();

  T accept<T>(StatementVisitor<T> visitor) =>
      visitor.visitVariableDeclaration(this);

  String toString() {
    var buffer = StringBuffer("\$");
    if (namespace != null) buffer.write("$namespace.");
    buffer.write("$name: $expression;");
    return buffer.toString();
  }
}
