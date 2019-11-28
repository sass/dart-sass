// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../logger.dart';
import '../../../parse/scss.dart';
import '../../../visitor/interface/statement.dart';
import '../configured_variable.dart';
import '../expression/string.dart';
import '../statement.dart';

/// A `@use` rule.
class UseRule implements Statement {
  /// The URI of the module to use.
  ///
  /// If this is relative, it's relative to the containing file.
  final Uri url;

  /// The namespace for members of the used module, or `null` if the members
  /// can be accessed without a namespace.
  final String namespace;

  /// A list of variable assignments used to configure the loaded modules.
  final List<ConfiguredVariable> configuration;

  final FileSpan span;

  UseRule(this.url, this.namespace, this.span,
      {Iterable<ConfiguredVariable> configuration})
      : configuration = configuration == null
            ? const []
            : List.unmodifiable(configuration) {
    for (var variable in this.configuration) {
      if (variable.isGuarded) {
        throw ArgumentError.value(variable, "configured variable",
            "can't be guarded in a @use rule.");
      }
    }
  }

  /// Parses a `@use` rule from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory UseRule.parse(String contents, {Object url, Logger logger}) =>
      ScssParser(contents, url: url, logger: logger).parseUseRule();

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitUseRule(this);

  String toString() {
    var buffer =
        StringBuffer("@use ${StringExpression.quoteText(url.toString())}");

    var basename = url.pathSegments.isEmpty ? "" : url.pathSegments.last;
    var dot = basename.indexOf(".");
    if (namespace != basename.substring(0, dot == -1 ? basename.length : dot)) {
      buffer.write(" as ${namespace ?? "*"}");
    }

    if (configuration.isNotEmpty) {
      buffer.write(" with (${configuration.join(", ")})");
    }

    buffer.write(";");
    return buffer.toString();
  }
}
