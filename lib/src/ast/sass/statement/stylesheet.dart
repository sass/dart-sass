// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../../../logger.dart';
import '../../../parse/css.dart';
import '../../../parse/sass.dart';
import '../../../parse/scss.dart';
import '../../../syntax.dart';
import '../statement.dart';
import 'parent.dart';

/// A Sass stylesheet.
///
/// This is the root Sass node. It contains top-level statements.
class Stylesheet extends ParentStatement {
  final FileSpan span;

  /// Whether this was parsed from a plain CSS stylesheet.
  final bool plainCss;

  Stylesheet(Iterable<Statement> children, this.span, {this.plainCss: false})
      : super(new List.unmodifiable(children));

  /// Parses a stylesheet from [contents] according to [syntax].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parse(String contents, Syntax syntax,
      {url, Logger logger}) {
    switch (syntax) {
      case Syntax.sass:
        return new Stylesheet.parseSass(contents, url: url, logger: logger);
      case Syntax.scss:
        return new Stylesheet.parseScss(contents, url: url, logger: logger);
      case Syntax.css:
        return new Stylesheet.parseCss(contents, url: url, logger: logger);
      default:
        throw new ArgumentError("Unknown syntax $syntax.");
    }
  }

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

  /// Parses a plain CSS stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseCss(String contents, {url, Logger logger}) =>
      new CssParser(contents, url: url, logger: logger).parse();

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitStylesheet(this);

  String toString() => children.join(" ");
}
