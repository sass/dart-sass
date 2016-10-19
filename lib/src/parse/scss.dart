// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import '../util/character.dart';
import 'stylesheet.dart';

/// A parser for the CSS-compatible syntax.
class ScssParser extends StylesheetParser {
  bool get indented => false;
  int get currentIndentation => null;

  ScssParser(String contents, {url}) : super(contents, url: url);

  bool atEndOfStatement() {
    var next = scanner.peekChar();
    return next == null ||
        next == $semicolon ||
        next == $rbrace ||
        next == $lbrace;
  }

  bool lookingAtChildren() => scanner.peekChar() == $lbrace;

  bool scanElse(int _) {
    var start = scanner.state;
    whitespace();
    if (scanner.scanChar($at) && scanIdentifier('else')) return true;
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
          children.add(variableDeclaration());
          break;

        case $slash:
          switch (scanner.peekChar(1)) {
            case $slash:
              children.add(_silentComment());
              whitespaceWithoutComments();
              break;
            case $asterisk:
              children.add(_loudComment());
              whitespaceWithoutComments();
              break;
            default:
              children.add(child());
              break;
          }
          break;

        case $semicolon:
          scanner.readChar();
          whitespaceWithoutComments();
          break;

        case $rbrace:
          scanner.expectChar($rbrace);
          whitespaceWithoutComments();
          return children;

        default:
          children.add(child());
          break;
      }
    }
  }

  List<Statement> statements(Statement statement()) {
    var statements = <Statement>[];
    whitespaceWithoutComments();
    while (!scanner.isDone) {
      switch (scanner.peekChar()) {
        case $dollar:
          statements.add(variableDeclaration());
          break;

        case $slash:
          switch (scanner.peekChar(1)) {
            case $slash:
              statements.add(_silentComment());
              whitespaceWithoutComments();
              break;
            case $asterisk:
              statements.add(_loudComment());
              whitespaceWithoutComments();
              break;
            default:
              var child = statement();
              if (child != null) statements.add(child);
              break;
          }
          break;

        case $semicolon:
          scanner.readChar();
          whitespaceWithoutComments();
          break;

        default:
          var child = statement();
          if (child != null) statements.add(child);
          break;
      }
    }
    return statements;
  }

  /// Consumes a statement-level silent comment block.
  Comment _silentComment() {
    var start = scanner.state;
    scanner.expect("//");

    do {
      while (!scanner.isDone && !isNewline(scanner.readChar())) {}
      if (scanner.isDone) break;
      whitespaceWithoutComments();
    } while (scanner.scan("//"));

    return new Comment(
        scanner.substring(start.position), scanner.spanFrom(start),
        silent: true);
  }

  /// Consumes a statement-level loud comment block.
  Comment _loudComment() {
    var start = scanner.state;
    scanner.expect("/*");
    do {
      while (scanner.readChar() != $asterisk) {}
    } while (scanner.readChar() != $slash);

    return new Comment(
        scanner.substring(start.position), scanner.spanFrom(start),
        silent: false);
  }
}
