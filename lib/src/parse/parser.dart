// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../exception.dart';
import '../util/character.dart';

abstract class Parser {
  final SpanScanner scanner;

  Parser(String contents, {url})
      : scanner = new SpanScanner(contents, sourceUrl: url);

  // ## Tokens

  bool scanWhitespace() {
    var start = scanner.position;
    whitespace();
    return scanner.position != start;
  }

  void whitespace() {
    do {
      whitespaceWithoutComments();
    } while (comment());
  }

  void whitespaceWithoutComments() {
    while (!scanner.isDone && isWhitespace(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  bool comment() {
    if (scanner.peekChar() != $slash) return false;

    var next = scanner.peekChar(1);
    if (next == $slash) {
      silentComment();
      return true;
    } else if (next == $asterisk) {
      loudComment();
      return true;
    } else {
      return false;
    }
  }

  void silentComment() {
    scanner.expect("//");
    while (!scanner.isDone && !isNewline(scanner.readChar())) {}
  }

  void loudComment() {
    scanner.expect("/*");
    do {
      while (scanner.readChar() != $asterisk) {}
    } while (scanner.readChar() != $slash);
  }

  String identifier() {
    var text = new StringBuffer();
    while (scanner.scanChar($dash)) {
      text.writeCharCode($dash);
    }

    var first = scanner.peekChar();
    if (first == null) {
      scanner.error("Expected identifier.");
    } else if (isNameStart(first)) {
      text.writeCharCode(scanner.readChar());
    } else if (first == $backslash) {
      text.writeCharCode(escape());
    } else {
      scanner.error("Expected identifier.");
    }

    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (isName(next)) {
        text.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        text.writeCharCode(escape());
      } else {
        break;
      }
    }

    return text.toString();
  }

  String string() {
    // NOTE: this logic is largely duplicated in ScssParser._interpolatedString.
    // Most changes here should be mirrored there.

    var quote = scanner.readChar();
    if (quote != $single_quote && quote != $double_quote) {
      scanner.error("Expected string.",
          position: quote == null ? scanner.position : scanner.position - 1);
    }

    var buffer = new StringBuffer();
    while (true) {
      var next = scanner.peekChar();
      if (next == quote) {
        scanner.readChar();
        break;
      } else if (next == null || isNewline(next)) {
        scanner.error("Expected ${new String.fromCharCode(quote)}.");
      } else if (next == $backslash) {
        if (isNewline(scanner.peekChar(1))) {
          scanner.readChar();
          scanner.readChar();
        } else {
          buffer.writeCharCode(escape());
        }
      } else {
        buffer.writeCharCode(scanner.readChar());
      }
    }

    return buffer.toString();
  }

  String declarationValue() {
    // NOTE: this logic is largely duplicated in
    // ScssParser._interpolatedDeclarationValue. Most changes here should be
    // mirrored there.

    var buffer = new StringBuffer();
    var brackets = <int>[];
    var wroteNewline = false;
    loop:
    while (true) {
      var next = scanner.peekChar();
      switch (next) {
        case $backslash:
          buffer.writeCharCode(escape());
          wroteNewline = false;
          break;

        case $double_quote:
        case $single_quote:
          buffer.write(rawText(string));
          wroteNewline = false;
          break;

        case $slash:
          if (scanner.peekChar(1) == $asterisk) {
            buffer.write(rawText(loudComment));
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          wroteNewline = false;
          break;

        case $space:
        case $tab:
          if (wroteNewline || !isWhitespace(scanner.peekChar(1))) {
            buffer.writeCharCode($space);
          }
          scanner.readChar();
          break;

        case $lf:
        case $cr:
        case $ff:
          if (!isNewline(scanner.peekChar(-1))) buffer.writeln();
          scanner.readChar();
          wroteNewline = true;
          break;

        case $lparen:
        case $lbrace:
        case $lbracket:
          buffer.writeCharCode(next);
          brackets.add(opposite(scanner.readChar()));
          wroteNewline = false;
          break;

        case $rparen:
        case $rbrace:
        case $rbracket:
          if (brackets.isEmpty) break loop;
          buffer.writeCharCode(next);
          scanner.expectChar(brackets.removeLast());
          wroteNewline = false;
          break;

        case $exclamation:
        case $semicolon:
          break loop;

        default:
          if (next == null) break loop;

          // TODO: support url()
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;
          break;
      }
    }

    if (brackets.isNotEmpty) scanner.expectChar(brackets.last);
    return buffer.toString();
  }

  String variableName() {
    scanner.expectChar($dollar);
    return identifier();
  }

  // ## Characters

  int escape() {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    scanner.expectChar($backslash);
    var first = scanner.peekChar();
    if (first == null) {
      return 0xFFFD;
    } else if (isNewline(first)) {
      scanner.error("Expected escape sequence.");
      return 0;
    } else if (isHex(first)) {
      var value = 0;
      for (var i = 0; i < 6; i++) {
        var next = scanner.peekChar();
        if (next == null || !isHex(next)) break;
        value = (value << 4) + asHex(scanner.readChar());
      }
      if (isWhitespace(scanner.peekChar())) scanner.readChar();

      if (value == 0 ||
          (value >= 0xD800 && value <= 0xDFFF) ||
          value >= 0x10FFFF) {
        return 0xFFFD;
      } else {
        return value;
      }
    } else {
      return scanner.readChar();
    }
  }

  int readCharOrEscape() {
    var next = scanner.readChar();
    return next == $backslash ? escape() : next;
  }

  bool scanCharOrEscape(int expected, {bool ignoreCase: false}) {
    // TODO(nweiz): Test if it's faster to split this into separate methods for
    // case-sensitivity rather than checking the boolean each time.
    var actual = readCharOrEscape();
    return ignoreCase
        ? characterEqualsIgnoreCase(actual, expected)
        : actual == expected;
  }

  bool scanCharIgnoreCase(int letter) {
    if (!equalsLetterIgnoreCase(letter, scanner.peekChar())) return false;
    scanner.readChar();
    return true;
  }

  void expectCharIgnoreCase(int letter) {
    var actual = scanner.readChar();
    if (equalsLetterIgnoreCase(letter, actual)) return;

    scanner.error('Expected "${new String.fromCharCode(letter)}".',
        position: actual == null ? scanner.position : scanner.position - 1);
  }

  // ## Utilities

  /// This is based on [the CSS algorithm][], but it assumes all backslashes
  /// start escapes.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  bool lookingAtIdentifier() {
    // See also [ScssParser._lookingAtInterpolatedIdentifier].

    var first = scanner.peekChar();
    if (isNameStart(first) || first == $backslash) return true;

    if (first != $dash) return false;
    var second = scanner.peekChar(1);
    return isNameStart(second) || second == $dash || second == $backslash;
  }

  bool scanIdentifier(String text, {bool ignoreCase: false}) {
    if (!lookingAtIdentifier()) return false;

    var start = scanner.state;
    for (var i = 0; i < text.length; i++) {
      var next = text.codeUnitAt(i);
      if (scanCharOrEscape(next, ignoreCase: ignoreCase)) continue;
      scanner.state = start;
      return false;
    }

    var next = scanner.peekChar();
    if (next == null) return true;
    if (!isName(next) && next != $backslash) return true;
    scanner.state = start;
    return false;
  }

  void expectIdentifier(String text, {String name, bool ignoreCase: false}) {
    name ??= '"$text"';

    var start = scanner.position;
    for (var i = 0; i < text.length; i++) {
      var next = text.codeUnitAt(i);
      if (scanCharOrEscape(next, ignoreCase: ignoreCase)) continue;
      scanner.error("Expected $name.", position: start);
    }

    var next = scanner.peekChar();
    if (next == null) return;
    if (!isName(next) && next != $backslash) return;
    scanner.error("Expected $name", position: start);
  }

  String rawText(void consumer()) {
    var start = scanner.position;
    consumer();
    return scanner.substring(start);
  }

  /*=T*/ wrapFormatException/*<T>*/(/*=T*/ callback()) {
    try {
      return callback();
    } on StringScannerException catch (error) {
      throw new SassException(error.message, error.span as FileSpan);
    }
  }
}
