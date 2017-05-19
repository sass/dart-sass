// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../../../parse/sass.dart';
import '../../../parse/scss.dart';
import '../statement.dart';

/// A Sass stylesheet.
///
/// This is the root Sass node. It contains top-level statements.
class Stylesheet implements Statement {
  /// The top-level statements of this Sass stylesheet.
  final List<Statement> children;

  final FileSpan span;

  Stylesheet(Iterable<Statement> children, this.span)
      : children = new List.unmodifiable(children);

  /// Parses an indented-syntax stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes. If
  /// [color] is `true`, this will use terminal colors in warnings.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseSass(String contents, {url, bool color: false}) =>
      new SassParser(contents, url: url, color: color).parse();

  /// Parses an SCSS stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes. If
  /// [color] is `true`, this will use terminal colors in warnings.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseScss(String contents, {url, bool color: false}) =>
      new ScssParser(contents, url: url, color: color).parse();

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitStylesheet(this);

  String toString() => children.join(" ");
}
