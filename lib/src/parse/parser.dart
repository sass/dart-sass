// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../exception.dart';
import '../logger.dart';
import '../util/character.dart';

/// The abstract base class for all parsers.
///
/// This provides utility methods and common token parsing. Unless specified
/// otherwise, a parse method throws a [SassFormatException] if it fails to
/// parse.
abstract class Parser {
  /// The scanner that scans through the text being parsed.
  final SpanScanner scanner;

  /// The logger to use when emitting warnings.
  @protected
  final Logger logger;

  Parser(String contents, {url, Logger logger})
      : scanner = new SpanScanner(contents, sourceUrl: url),
        logger = logger ?? const Logger.stderr();

  // ## Tokens

  /// Consumes whitespace, including any comments.
  @protected
  void whitespace() {
    do {
      whitespaceWithoutComments();
    } while (scanComment());
  }

  /// Like [whitespace], but returns whether any was consumed.
  @protected
  bool scanWhitespace() {
    var start = scanner.position;
    whitespace();
    return scanner.position != start;
  }

  /// Consumes whitespace, but not comments.
  @protected
  void whitespaceWithoutComments() {
    while (!scanner.isDone && isWhitespace(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  /// Consumes spaces and tabs.
  @protected
  void spaces() {
    while (!scanner.isDone && isSpaceOrTab(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  /// Consumes and ignores a comment if possible.
  ///
  /// Returns whether the comment was consumed.
  @protected
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
  @protected
  void silentComment() {
    scanner.expect("//");
    while (!scanner.isDone && !isNewline(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  /// Consumes and ignores a loud (CSS-style) comment.
  @protected
  void loudComment() {
    scanner.expect("/*");
    while (true) {
      var next = scanner.readChar();
      if (next != $asterisk) continue;

      do {
        next = scanner.readChar();
      } while (next == $asterisk);
      if (next == $slash) break;
    }
  }

  /// Consumes a plain CSS identifier.
  ///
  /// If [unit] is `true`, this doesn't parse a `-` followed by a digit. This
  /// ensures that `1px-2px` parses as subtraction rather than the unit
  /// `px-2px`.
  @protected
  String identifier({bool unit: false}) {
    // NOTE: this logic is largely duplicated in
    // StylesheetParser._interpolatedIdentifier. Most changes here should be
    // mirrored there.

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
      text.write(escape(identifierStart: true));
    } else {
      scanner.error("Expected identifier.");
    }

    _identifierBody(text, unit: unit);
    return text.toString();
  }

  /// Consumes a chunk of a plain CSS identifier after the name start.
  @protected
  String identifierBody() {
    var text = new StringBuffer();
    _identifierBody(text);
    if (text.isEmpty) scanner.error("Expected identifier body.");
    return text.toString();
  }

  /// Like [_identifierBody], but parses the body into the [text] buffer.
  void _identifierBody(StringBuffer text, {bool unit: false}) {
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (unit && next == $dash) {
        // Disallow `-` followed by a dot or a digit digit in units.
        var second = scanner.peekChar(1);
        if (second != null && (second == $dot || isDigit(second))) break;
        text.writeCharCode(scanner.readChar());
      } else if (isName(next)) {
        text.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        text.write(escape());
      } else {
        break;
      }
    }
  }

  /// Consumes a plain CSS string.
  ///
  /// This returns the parsed contents of the string—that is, it doesn't include
  /// quotes and its escapes are resolved.
  @protected
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

  /// Consumes tokens until it reaches a top-level `";"`, `")"`, `"]"`,
  /// or `"}"` and returns their contents as a string.
  ///
  /// If [allowEmpty] is `false` (the default), this requires at least one token.
  @protected
  String declarationValue({bool allowEmpty: false}) {
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
          buffer.write(escape(identifierStart: true));
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

        case $semicolon:
          if (brackets.isEmpty) break loop;
          buffer.writeCharCode(scanner.readChar());
          break;

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
    if (!allowEmpty && buffer.isEmpty) scanner.error("Expected token.");
    return buffer.toString();
  }

  /// Consumes a `url()` token if possible, and returns `null` otherwise.
  @protected
  String tryUrl() {
    // NOTE: this logic is largely duplicated in ScssParser._tryUrlContents.
    // Most changes here should be mirrored there.

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
  @protected
  String variableName() {
    scanner.expectChar($dollar);
    return identifier();
  }

  // ## Characters

  /// Consumes an escape sequence and returns the text that defines it.
  ///
  /// If [identifierStart] is true, this normalizes the escape sequence as
  /// though it were at the beginning of an identifier.
  @protected
  String escape({bool identifierStart: false}) {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    scanner.expectChar($backslash);
    var value = 0;
    var first = scanner.peekChar();
    if (first == null) {
      return "";
    } else if (isNewline(first)) {
      scanner.error("Expected escape sequence.");
      return null;
    } else if (isHex(first)) {
      for (var i = 0; i < 6; i++) {
        var next = scanner.peekChar();
        if (next == null || !isHex(next)) break;
        value *= 16;
        value += asHex(scanner.readChar());
      }

      scanCharIf(isWhitespace);
    } else {
      value = scanner.readChar();
    }

    if (identifierStart ? isNameStart(value) : isName(value)) {
      return new String.fromCharCode(value);
    } else if (value <= 0x1F ||
        value == 0x7F ||
        (identifierStart && isDigit(value))) {
      var buffer = new StringBuffer()..writeCharCode($backslash);
      if (value > 0xF) buffer.writeCharCode(hexCharFor(value >> 4));
      buffer.writeCharCode(hexCharFor(value & 0xF));
      buffer.writeCharCode($space);
      return buffer.toString();
    } else {
      return new String.fromCharCodes([$backslash, value]);
    }
  }

  /// Consumes an escape sequence and returns the character it represents.
  @protected
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
  @protected
  bool scanCharIf(bool condition(int character)) {
    var next = scanner.peekChar();
    if (!condition(next)) return false;
    scanner.readChar();
    return true;
  }

  /// Consumes the next character if it's equal to [letter], ignoring ASCII
  /// case.
  @protected
  bool scanCharIgnoreCase(int letter) {
    if (!equalsLetterIgnoreCase(letter, scanner.peekChar())) return false;
    scanner.readChar();
    return true;
  }

  /// Consumes the next character and asserts that it's equal to [letter],
  /// ignoring ASCII case.
  @protected
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
  @protected
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
  /// If [forward] is passed, this looks that many characters forward instead.
  ///
  /// This is based on [the CSS algorithm][], but it assumes all backslashes
  /// start escapes.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  @protected
  bool lookingAtIdentifier([int forward]) {
    // See also [ScssParser._lookingAtInterpolatedIdentifier].

    forward ??= 0;
    var first = scanner.peekChar(forward);
    if (first == null) return false;
    if (isNameStart(first) || first == $backslash) return true;
    if (first != $dash) return false;

    var second = scanner.peekChar(forward + 1);
    if (second == null) return false;
    if (isNameStart(second) || second == $backslash) return true;
    if (second != $dash) return false;

    var third = scanner.peekChar(forward + 2);
    return third != null && isNameStart(third);
  }

  /// Returns whether the scanner is immediately before a sequence of characters
  /// that could be part of a plain CSS identifier body.
  @protected
  bool lookingAtIdentifierBody() {
    var next = scanner.peekChar();
    return next != null && (isName(next) || next == $backslash);
  }

  /// Consumes an identifier if its name exactly matches [text].
  ///
  /// If [ignoreCase] is `true`, does a case-insensitive match.
  @protected
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
  @protected
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
  @protected
  String rawText(void consumer()) {
    var start = scanner.position;
    consumer();
    return scanner.substring(start);
  }

  /// Prints a warning to standard error, associated with [span].
  @protected
  void warn(String message, FileSpan span) => logger.warn(message, span: span);

  /// Throws an error associated with [span].
  @protected
  @alwaysThrows
  void error(String message, FileSpan span) =>
      throw new StringScannerException(message, span, scanner.string);

  /// Prints a source span highlight of the current location being scanned.
  ///
  /// If [message] is passed, prints that as well. This is intended for use when
  /// debugging parser failures.
  @protected
  void debug([message]) {
    if (message == null) {
      print(scanner.emptySpan.highlight(color: true));
    } else {
      print(scanner.emptySpan.message(message.toString(), color: true));
    }
  }

  /// Runs [callback] and wraps any [SourceSpanFormatException] it throws in a
  /// [SassFormatException].
  @protected
  T wrapSpanFormatException<T>(T callback()) {
    try {
      return callback();
    } on SourceSpanFormatException catch (error) {
      var span = error.span as FileSpan;
      if (error.message.startsWith("Expected") && span.length == 0) {
        var startPosition = _firstNewlineBefore(span.start.offset);
        if (startPosition != span.start.offset) {
          span = span.file.span(startPosition, startPosition);
        }
      }

      throw new SassFormatException(error.message, span);
    }
  }

  /// If [position] is separated from the previous non-whitespace character in
  /// `scanner.string` by one or more newlines, returns the offset of the last
  /// separating newline.
  ///
  /// Otherwise returns [position].
  ///
  /// This helps avoid missing token errors pointing at the next closing bracket
  /// rather than the line where the problem actually occurred.
  int _firstNewlineBefore(int position) {
    var index = position - 1;
    int lastNewline;
    while (index >= 0) {
      var codeUnit = scanner.string.codeUnitAt(index);
      if (!isWhitespace(codeUnit)) return lastNewline ?? position;
      if (isNewline(codeUnit)) lastNewline = index;
      index--;
    }

    // If the document *only* contains whitespace before [position], always
    // return [position].
    return position;
  }
}
