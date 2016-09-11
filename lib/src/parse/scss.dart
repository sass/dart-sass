// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import '../util/character.dart';
import 'stylesheet.dart';

class ScssParser extends StylesheetParser {
  bool get indented => false;

  ScssParser(String contents, {url}) : super(contents, url: url);

  bool atEndOfStatement() {
    var next = scanner.peekChar();
    return next == null ||
        next == $semicolon ||
        next == $rbrace ||
        next == $lbrace;
  }

  bool lookingAtChildren() => scanner.peekChar() == $lbrace;

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
              break;
            case $asterisk:
              children.add(_loudComment());
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
              break;
            case $asterisk:
              statements.add(_loudComment());
              break;
            default:
              statements.add(statement());
              break;
          }
          break;

        case $semicolon:
          scanner.readChar();
          whitespaceWithoutComments();
          break;

        default:
          statements.add(statement());
          break;
      }
    }
    return statements;
  }

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
