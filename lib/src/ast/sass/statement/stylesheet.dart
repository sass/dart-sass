// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../../../logger.dart';
import '../../../parse/sass.dart';
import '../../../parse/scss.dart';
import '../statement.dart';
import 'parent.dart';

/// A Sass stylesheet.
///
/// This is the root Sass node. It contains top-level statements.
class Stylesheet extends ParentStatement {
  final FileSpan span;

  Stylesheet(Iterable<Statement> children, this.span)
      : super(new List.unmodifiable(children));

  /// Parses an indented-syntax stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseSass(String contents, {url, Logger logger}) =>
      new SassParser(contents, url: url, logger: logger).parse();

  /// Parses an SCSS stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseScss(String contents, {url, Logger logger}) =>
      new ScssParser(contents, url: url, logger: logger).parse();

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitStylesheet(this);

  String toString() => children.join(" ");
}
