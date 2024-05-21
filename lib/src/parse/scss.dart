// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import '../deprecation.g.dart';
import '../interpolation_buffer.dart';
import '../logger.dart';
import '../util/character.dart';
import 'stylesheet.dart';

/// A parser for the CSS-compatible syntax.
class ScssParser extends StylesheetParser {
  bool get indented => false;
  int get currentIndentation => 0;

  ScssParser(super.contents, {super.url, super.logger});

  Interpolation styleRuleSelector() => almostAnyValue();

  void expectStatementSeparator([String? name]) {
    whitespaceWithoutComments();
    if (scanner.isDone) return;
    if (scanner.peekChar() case $semicolon || $rbrace) return;
    scanner.expectChar($semicolon);
  }

  bool atEndOfStatement() {
    var next = scanner.peekChar();
    return next == null ||
        next == $semicolon ||
        next == $rbrace ||
        next == $lbrace;
  }

  bool lookingAtChildren() => scanner.peekChar() == $lbrace;

  bool scanElse(int ifIndentation) {
    var start = scanner.state;
    whitespace();
    var beforeAt = scanner.state;
    if (scanner.scanChar($at)) {
      if (scanIdentifier('else', caseSensitive: true)) return true;
      if (scanIdentifier('elseif', caseSensitive: true)) {
        logger.warnForDeprecation(
            Deprecation.elseif,
            '@elseif is deprecated and will not be supported in future Sass '
            'versions.\n'
            '\n'
            'Recommendation: @else if',
            span: scanner.spanFrom(beforeAt));
        scanner.position -= 2;
        return true;
      }
    }
    scanner.state = start;
    return false;
  }

  List<Statement> children(Statement child()) {
    scanner.expectChar($lbrace);
    whitespaceWithoutComments();
    var children = <Statement>[];
    while (true) {
      switch (scanner.peekChar()) {
        case $dollar:
          children.add(variableDeclarationWithoutNamespace());

        case $slash:
          switch (scanner.peekChar(1)) {
            case $slash:
              children.add(_silentComment());
              whitespaceWithoutComments();
            case $asterisk:
              children.add(_loudComment());
              whitespaceWithoutComments();
            default:
              children.add(child());
          }

        case $semicolon:
          scanner.readChar();
          whitespaceWithoutComments();

        case $rbrace:
          scanner.expectChar($rbrace);
          return children;

        default:
          children.add(child());
      }
    }
  }

  List<Statement> statements(Statement? statement()) {
    var statements = <Statement>[];
    whitespaceWithoutComments();
    while (!scanner.isDone) {
      switch (scanner.peekChar()) {
        case $dollar:
          statements.add(variableDeclarationWithoutNamespace());

        case $slash:
          switch (scanner.peekChar(1)) {
            case $slash:
              statements.add(_silentComment());
              whitespaceWithoutComments();
            case $asterisk:
              statements.add(_loudComment());
              whitespaceWithoutComments();
            default:
              if (statement() case var child?) statements.add(child);
          }

        case $semicolon:
          scanner.readChar();
          whitespaceWithoutComments();

        default:
          if (statement() case var child?) statements.add(child);
      }
    }
    return statements;
  }

  /// Consumes a statement-level silent comment block.
  SilentComment _silentComment() {
    var start = scanner.state;
    scanner.expect("//");

    do {
      while (!scanner.isDone && !scanner.readChar().isNewline) {}
      if (scanner.isDone) break;
      spaces();
    } while (scanner.scan("//"));

    if (plainCss) {
      error("Silent comments aren't allowed in plain CSS.",
          scanner.spanFrom(start));
    }

    return lastSilentComment = SilentComment(
        scanner.substring(start.position), scanner.spanFrom(start));
  }

  /// Consumes a statement-level loud comment block.
  LoudComment _loudComment() {
    var start = scanner.state;
    scanner.expect("/*");
    var buffer = InterpolationBuffer()..write("/*");
    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case $hash:
          if (scanner.peekChar(1) == $lbrace) {
            buffer.add(singleInterpolation());
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          break;

        case $asterisk:
          buffer.writeCharCode(scanner.readChar());
          if (scanner.peekChar() != $slash) continue loop;

          buffer.writeCharCode(scanner.readChar());
          return LoudComment(buffer.interpolation(scanner.spanFrom(start)));

        case $cr:
          scanner.readChar();
          if (scanner.peekChar() != $lf) buffer.writeCharCode($lf);

        case $ff:
          scanner.readChar();
          buffer.writeCharCode($lf);

        default:
          buffer.writeCharCode(scanner.readChar());
      }
    }
  }
}
