// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../exception.dart';
import '../util/character.dart';

/// The abstract base class for all parsers.
///
/// This provides utility methods and common token parsing. Unless specified
/// otherwise, a parse method throws a [SassFormatException] if it fails to
/// parse.
abstract class Parser {
  /// The scanner that scans through the text being parsed.
  final SpanScanner scanner;

  Parser(String contents, {url})
      : scanner = new SpanScanner(contents, sourceUrl: url);

  // ## Tokens

  /// Consumes whitespace, including any comments.
  void whitespace() {
    do {
      whitespaceWithoutComments();
    } while (scanComment());
  }

  /// Like [whitespace], but returns whether any was consumed.
  bool scanWhitespace() {
    var start = scanner.position;
    whitespace();
    return scanner.position != start;
  }

  /// Consumes whitespace, but not comments.
  void whitespaceWithoutComments() {
    while (!scanner.isDone && isWhitespace(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  /// Consumes and ignores a comment if possible.
  ///
  /// Returns whether the comment was consumed.
  bool scanComment() {
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

  /// Consumes and ignores a silent (Sass-style) comment.
  void silentComment() {
    scanner.expect("//");
    while (!scanner.isDone && !isNewline(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  /// Consumes and ignores a loud (CSS-style) comment.
  void loudComment() {
    scanner.expect("/*");
    do {
      while (scanner.readChar() != $asterisk) {}
    } while (scanner.readChar() != $slash);
  }

  /// Consumes a plain CSS identifier.
  ///
  /// If [unit] is `true`, this doesn't parse a `-` followed by a digit. This
  /// ensures that `1px-2px` parses as subtraction rather than the unit
  /// `px-2px`.
  String identifier({bool unit: false}) {
    // NOTE: this logic is largely duplicated in ScssParser.identifier.
    // Most changes here should be mirrored there.

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
      text.write(escape());
    } else {
      scanner.error("Expected identifier.");
    }

    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (unit && next == $dash) {
        // Disallow `-` followed by a digit in units.
        var second = scanner.peekChar(1);
        if (second != null && isDigit(second)) break;
        text.writeCharCode(scanner.readChar());
      } else if (isName(next)) {
        text.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        text.write(escape());
      } else {
        break;
      }
    }

    return text.toString();
  }

  /// Consumes a plain CSS string.
  ///
  /// This returns the parsed contents of the string—that is, it doesn't include
  /// quotes and its escapes are resolved.
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
          buffer.writeCharCode(escapeCharacter());
        }
      } else {
        buffer.writeCharCode(scanner.readChar());
      }
    }

    return buffer.toString();
  }

  /// Consumes tokens until it reaches a top-level `":"`, `"!"`, `")"`, `"]"`,
  /// or `"}"` and returns their contents as a string.
  String declarationValue() {
    // NOTE: this logic is largely duplicated in
    // StylesheetParser._interpolatedDeclarationValue. Most changes here should
    // be mirrored there.

    var buffer = new StringBuffer();
    var brackets = <int>[];
    var wroteNewline = false;
    loop:
    while (true) {
      var next = scanner.peekChar();
      switch (next) {
        case $backslash:
          buffer.write(escape());
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

        case $u:
        case $U:
          var url = tryUrl();
          if (url != null) {
            buffer.write(url);
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          wroteNewline = false;
          break;

        default:
          if (next == null) break loop;

          if (lookingAtIdentifier()) {
            buffer.write(identifier());
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          wroteNewline = false;
          break;
      }
    }

    if (brackets.isNotEmpty) scanner.expectChar(brackets.last);
    return buffer.toString();
  }

  /// Consumes a `url()` token if possible, and returns `null` otherwise.
  String tryUrl() {
    // NOTE: this logic is largely duplicated in ScssParser._urlContents and
    // ScssParser._tryUrlContents. Most changes here should be mirrored there.

    var start = scanner.state;
    if (!scanIdentifier("url", ignoreCase: true)) return null;

    if (!scanner.scanChar($lparen)) {
      scanner.state = start;
      return null;
    }

    whitespace();

    // Match Ruby Sass's behavior: parse a raw URL() if possible, and if not
    // backtrack and re-parse as a function expression.
    var buffer = new StringBuffer()..write("url(");
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $percent ||
          next == $ampersand ||
          next == $hash ||
          (next >= $asterisk && next <= $tilde) ||
          next >= 0x0080) {
        buffer.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        buffer.write(escape());
      } else if (isWhitespace(next)) {
        whitespace();
        if (scanner.peekChar() != $rparen) break;
      } else if (next == $rparen) {
        buffer.writeCharCode(scanner.readChar());
        return buffer.toString();
      } else {
        break;
      }
    }

    scanner.state = start;
    return null;
  }

  /// Consumes a Sass variable name, and returns its name without the dollar
  /// sign.
  String variableName() {
    scanner.expectChar($dollar);
    return identifier();
  }

  // ## Characters

  /// Consumes an escape sequence and returns the text that defines it.
  String escape() {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    var buffer = new StringBuffer();
    scanner.expectChar($backslash);
    buffer.writeCharCode($backslash);
    var first = scanner.peekChar();
    if (first == null) {
      // Do nothing.
    } else if (isNewline(first)) {
      scanner.error("Expected escape sequence.");
      return null;
    } else if (isHex(first)) {
      for (var i = 0; i < 6; i++) {
        var next = scanner.peekChar();
        if (next == null || !isHex(next)) break;
        buffer.writeCharCode(scanner.readChar());
      }

      if (isWhitespace(scanner.peekChar())) {
        buffer.writeCharCode(scanner.readChar());
      }
    } else {
      buffer.writeCharCode(scanner.readChar());
    }

    return buffer.toString();
  }

  /// Consumes an escape sequence and returns the character it represents.
  int escapeCharacter() {
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

  // Consumes the next character if it matches [condition].
  //
  // Returns whether or not the character was consumed.
  bool scanCharIf(bool condition(int character)) {
    var next = scanner.peekChar();
    if (!condition(next)) return false;
    scanner.readChar();
    return true;
  }

  /// Consumes the next character if it's equal to [letter], ignoring ASCII
  /// case.
  bool scanCharIgnoreCase(int letter) {
    if (!equalsLetterIgnoreCase(letter, scanner.peekChar())) return false;
    scanner.readChar();
    return true;
  }

  /// Consumes the next character and asserts that it's equal to [letter],
  /// ignoring ASCII case.
  void expectCharIgnoreCase(int letter) {
    var actual = scanner.readChar();
    if (equalsLetterIgnoreCase(letter, actual)) return;

    scanner.error('Expected "${new String.fromCharCode(letter)}".',
        position: actual == null ? scanner.position : scanner.position - 1);
  }

  // ## Utilities

  /// Returns whether the scanner is immediately before a number.
  ///
  /// This follows [the CSS algorithm][].
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#starts-with-a-number
  bool lookingAtNumber() {
    var first = scanner.peekChar();
    if (first == null) return false;
    if (isDigit(first)) return true;

    if (first == $dot) {
      var second = scanner.peekChar(1);
      return second != null && isDigit(second);
    } else if (first == $plus || first == $minus) {
      var second = scanner.peekChar(1);
      if (second == null) return false;
      if (isDigit(second)) return true;
      if (second != $dot) return false;

      var third = scanner.peekChar(2);
      return third != null && isDigit(third);
    } else {
      return false;
    }
  }

  /// Returns whether the scanner is immediately before a plain CSS identifier.
  ///
  /// This is based on [the CSS algorithm][], but it assumes all backslashes
  /// start escapes.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  bool lookingAtIdentifier() {
    // See also [ScssParser._lookingAtInterpolatedIdentifier].

    var first = scanner.peekChar();
    if (first == null) return false;
    if (isNameStart(first) || first == $backslash) return true;

    if (first != $dash) return false;
    var second = scanner.peekChar(1);
    return second != null &&
        (isNameStart(second) || second == $dash || second == $backslash);
  }

  /// Returns whether the scanner is immediately before a sequence of characters
  /// that could be part of a plain CSS identifier body.
  bool lookingAtIdentifierBody() {
    var next = scanner.peekChar();
    return next != null && (isName(next) || next == $backslash);
  }

  /// Consumes an identifier if its name exactly matches [text].
  ///
  /// If [ignoreCase] is `true`, does a case-insensitive match.
  bool scanIdentifier(String text, {bool ignoreCase: false}) {
    if (!lookingAtIdentifier()) return false;

    var start = scanner.state;
    for (var i = 0; i < text.length; i++) {
      var next = text.codeUnitAt(i);
      if (scanCharIgnoreCase(next)) continue;
      scanner.state = start;
      return false;
    }

    if (!lookingAtIdentifierBody()) return true;
    scanner.state = start;
    return false;
  }

  /// Consumes an identifier and asserts that its name exactly matches [text].
  ///
  /// If [ignoreCase] is `true`, does a case-insensitive match.
  void expectIdentifier(String text, {String name, bool ignoreCase: false}) {
    name ??= '"$text"';

    var start = scanner.position;
    for (var i = 0; i < text.length; i++) {
      var next = text.codeUnitAt(i);
      if (scanCharIgnoreCase(next)) continue;
      scanner.error("Expected $name.", position: start);
    }

    if (!lookingAtIdentifierBody()) return;
    scanner.error("Expected $name", position: start);
  }

  /// Runs [consumer] and returns the source text that it consumes.
  String rawText(void consumer()) {
    var start = scanner.position;
    consumer();
    return scanner.substring(start);
  }

  /// Prints a source span highlight of the current location being scanned.
  ///
  /// If [message] is passed, prints that as well. This is intended for use when
  /// debugging parser failures.
  void debug([String message]) {
    if (message == null) {
      print(scanner.emptySpan.highlight(color: true));
    } else {
      print(scanner.emptySpan.message(message, color: true));
    }
  }

  /// Runs [callback] and wraps any [SourceSpanFormatException] it throws in a
  /// [SassFormatException].
  /*=T*/ wrapSpanFormatException/*<T>*/(/*=T*/ callback()) {
    try {
      return callback();
    } on SourceSpanFormatException catch (error) {
      throw new SassFormatException(error.message, error.span as FileSpan);
    }
  }
}
