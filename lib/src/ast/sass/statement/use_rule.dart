// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:tuple/tuple.dart';

import '../../../logger.dart';
import '../../../parse/scss.dart';
import '../../../visitor/interface/statement.dart';
import '../expression.dart';
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

  /// A map from variable names to their values and the spans for those
  /// variables, used to configure the loaded modules.
  final Map<String, Tuple2<Expression, FileSpan>> configuration;

  final FileSpan span;

  UseRule(this.url, this.namespace, this.span,
      {Map<String, Tuple2<Expression, FileSpan>> configuration})
      : configuration = Map.unmodifiable(configuration ?? const {});

  /// Parses a `@use` rule from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory UseRule.parse(String contents, {url, Logger logger}) =>
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
      buffer.write(" with (");
      buffer.write(configuration.entries
          .map((entry) => "\$${entry.key}: ${entry.value.item1}")
          .join(", "));
      buffer.write(")");
    }

    buffer.write(";");
    return buffer.toString();
  }
}
