// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../exception.dart';
import '../../../logger.dart';
import '../../../parse/css.dart';
import '../../../parse/sass.dart';
import '../../../parse/scss.dart';
import '../../../syntax.dart';
import '../../../utils.dart';
import '../../../visitor/interface/statement.dart';
import '../statement.dart';
import 'forward_rule.dart';
import 'loud_comment.dart';
import 'parent.dart';
import 'silent_comment.dart';
import 'use_rule.dart';
import 'variable_declaration.dart';

/// A Sass stylesheet.
///
/// This is the root Sass node. It contains top-level statements.
///
/// {@category AST}
/// {@category Parsing}
final class Stylesheet extends ParentStatement<List<Statement>> {
  final FileSpan span;

  /// Whether this was parsed from a plain CSS stylesheet.
  ///
  /// @nodoc
  @internal
  final bool plainCss;

  /// All the `@use` rules that appear in this stylesheet.
  List<UseRule> get uses => UnmodifiableListView(_uses);
  final _uses = <UseRule>[];

  /// All the `@forward` rules that appear in this stylesheet.
  List<ForwardRule> get forwards => UnmodifiableListView(_forwards);
  final _forwards = <ForwardRule>[];

  Stylesheet(Iterable<Statement> children, FileSpan span)
      : this.internal(children, span);

  /// A separate internal constructor that allows [plainCss] to be set.
  ///
  /// @nodoc
  @internal
  Stylesheet.internal(Iterable<Statement> children, this.span,
      {this.plainCss = false})
      : super(List.unmodifiable(children)) {
    loop:
    for (var child in this.children) {
      switch (child) {
        case UseRule():
          _uses.add(child);

        case ForwardRule():
          _forwards.add(child);

        case SilentComment() || LoudComment() || VariableDeclaration():
          // These are allowed between `@use` and `@forward` rules.
          break;

        case _:
          break loop;
        // Once we reach anything else, we know we're done with loads.
      }
    }
  }

  /// Parses a stylesheet from [contents] according to [syntax].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parse(String contents, Syntax syntax,
      {Object? url, Logger? logger}) {
    try {
      switch (syntax) {
        case Syntax.sass:
          return Stylesheet.parseSass(contents, url: url, logger: logger);
        case Syntax.scss:
          return Stylesheet.parseScss(contents, url: url, logger: logger);
        case Syntax.css:
          return Stylesheet.parseCss(contents, url: url, logger: logger);
        default:
          throw ArgumentError("Unknown syntax $syntax.");
      }
    } on SassException catch (error, stackTrace) {
      var url = error.span.sourceUrl;
      if (url == null || url.toString() == 'stdin') rethrow;

      throw throwWithTrace(
          error.withLoadedUrls(Set.unmodifiable({url})), error, stackTrace);
    }
  }

  /// Parses an indented-syntax stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseSass(String contents,
          {Object? url, Logger? logger}) =>
      SassParser(contents, url: url, logger: logger).parse();

  /// Parses an SCSS stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseScss(String contents,
          {Object? url, Logger? logger}) =>
      ScssParser(contents, url: url, logger: logger).parse();

  /// Parses a plain CSS stylesheet from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Stylesheet.parseCss(String contents, {Object? url, Logger? logger}) =>
      CssParser(contents, url: url, logger: logger).parse();

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitStylesheet(this);

  String toString() => children.join(" ");
}
