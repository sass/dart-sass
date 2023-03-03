// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../exception.dart';
import '../interpolation_map.dart';
import '../logger.dart';
import '../util/character.dart';
import '../utils.dart';

/// The abstract base class for all parsers.
///
/// This provides utility methods and common token parsing. Unless specified
/// otherwise, a parse method throws a [SassFormatException] if it fails to
/// parse.
class Parser {
  /// The scanner that scans through the text being parsed.
  final SpanScanner scanner;

  /// The logger to use when emitting warnings.
  @protected
  final Logger logger;

  /// A map used to map source spans in the text being parsed back to their
  /// original locations in the source file, if this isn't being parsed directly
  /// from source.
  final InterpolationMap? _interpolationMap;

  /// Parses [text] as a CSS identifier and returns the result.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  static String parseIdentifier(String text, {Logger? logger}) =>
      Parser(text, logger: logger)._parseIdentifier();

  /// Returns whether [text] is a valid CSS identifier.
  static bool isIdentifier(String text, {Logger? logger}) {
    try {
      parseIdentifier(text, logger: logger);
      return true;
    } on SassFormatException {
      return false;
    }
  }

  /// Returns whether [text] starts like a variable declaration.
  ///
  /// Ignores everything after the `:`.
  static bool isVariableDeclarationLike(String text, {Logger? logger}) =>
      Parser(text, logger: logger)._isVariableDeclarationLike();

  @protected
  Parser(String contents,
      {Object? url, Logger? logger, InterpolationMap? interpolationMap})
      : scanner = SpanScanner(contents, sourceUrl: url),
        logger = logger ?? const Logger.stderr(),
        _interpolationMap = interpolationMap;

  String _parseIdentifier() {
    return wrapSpanFormatException(() {
      var result = identifier();
      scanner.expectDone();
      return result;
    });
  }

  bool _isVariableDeclarationLike() {
    if (!scanner.scanChar($dollar)) return false;
    if (!lookingAtIdentifier()) return false;
    identifier();
    whitespace();
    return scanner.scanChar($colon);
  }

  // ## Tokens

  /// Consumes whitespace, including any comments.
  @protected
  void whitespace() {
    do {
      whitespaceWithoutComments();
    } while (scanComment());
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

  /// Like [whitespace], but throws an error if no whitespace is consumed.
  @protected
  void expectWhitespace() {
    if (scanner.isDone ||
        !(isWhitespace(scanner.peekChar()) || scanComment())) {
      scanner.error("Expected whitespace.");
    }

    whitespace();
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
  /// If [normalize] is `true`, this converts underscores into hyphens.
  ///
  /// If [unit] is `true`, this doesn't parse a `-` followed by a digit. This
  /// ensures that `1px-2px` parses as subtraction rather than the unit
  /// `px-2px`.
  @protected
  String identifier({bool normalize = false, bool unit = false}) {
    // NOTE: this logic is largely duplicated in
    // StylesheetParser.interpolatedIdentifier. Most changes here should be
    // mirrored there.

    var text = StringBuffer();
    if (scanner.scanChar($dash)) {
      text.writeCharCode($dash);

      if (scanner.scanChar($dash)) {
        text.writeCharCode($dash);
        _identifierBody(text, normalize: normalize, unit: unit);
        return text.toString();
      }
    }

    var first = scanner.peekChar();
    if (first == null) {
      scanner.error("Expected identifier.");
    } else if (normalize && first == $underscore) {
      scanner.readChar();
      text.writeCharCode($dash);
    } else if (isNameStart(first)) {
      text.writeCharCode(scanner.readChar());
    } else if (first == $backslash) {
      text.write(escape(identifierStart: true));
    } else {
      scanner.error("Expected identifier.");
    }

    _identifierBody(text, normalize: normalize, unit: unit);
    return text.toString();
  }

  /// Consumes a chunk of a plain CSS identifier after the name start.
  @protected
  String identifierBody() {
    var text = StringBuffer();
    _identifierBody(text);
    if (text.isEmpty) scanner.error("Expected identifier body.");
    return text.toString();
  }

  /// Like [_identifierBody], but parses the body into the [text] buffer.
  void _identifierBody(StringBuffer text,
      {bool normalize = false, bool unit = false}) {
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (unit && next == $dash) {
        // Disallow `-` followed by a dot or a digit digit in units.
        var second = scanner.peekChar(1);
        if (second != null && (second == $dot || isDigit(second))) break;
        text.writeCharCode(scanner.readChar());
      } else if (normalize && next == $underscore) {
        scanner.readChar();
        text.writeCharCode($dash);
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
      scanner.error("Expected string.", position: scanner.position - 1);
    }

    var buffer = StringBuffer();
    while (true) {
      var next = scanner.peekChar();
      if (next == quote) {
        scanner.readChar();
        break;
      } else if (next == null || isNewline(next)) {
        scanner.error("Expected ${String.fromCharCode(quote)}.");
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

  /// Consumes and returns a natural number (that is, a non-negative integer) as
  /// a double.
  ///
  /// Doesn't support scientific notation.
  @protected
  double naturalNumber() {
    var first = scanner.readChar();
    if (!isDigit(first)) {
      scanner.error("Expected digit.", position: scanner.position - 1);
    }

    var number = asDecimal(first).toDouble();
    while (isDigit(scanner.peekChar())) {
      number *= 10;
      number += asDecimal(scanner.readChar());
    }
    return number;
  }

  /// Consumes tokens until it reaches a top-level `";"`, `")"`, `"]"`,
  /// or `"}"` and returns their contents as a string.
  ///
  /// If [allowEmpty] is `false` (the default), this requires at least one token.
  @protected
  String declarationValue({bool allowEmpty = false}) {
    // NOTE: this logic is largely duplicated in
    // StylesheetParser._interpolatedDeclarationValue. Most changes here should
    // be mirrored there.

    var buffer = StringBuffer();
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
          buffer.writeCharCode(next!); // dart-lang/sdk#45357
          brackets.add(opposite(scanner.readChar()));
          wroteNewline = false;
          break;

        case $rparen:
        case $rbrace:
        case $rbracket:
          if (brackets.isEmpty) break loop;
          buffer.writeCharCode(next!); // dart-lang/sdk#45357
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
  String? tryUrl() {
    // NOTE: this logic is largely duplicated in ScssParser._tryUrlContents.
    // Most changes here should be mirrored there.

    var start = scanner.state;
    if (!scanIdentifier("url")) return null;

    if (!scanner.scanChar($lparen)) {
      scanner.state = start;
      return null;
    }

    whitespace();

    // Match Ruby Sass's behavior: parse a raw URL() if possible, and if not
    // backtrack and re-parse as a function expression.
    var buffer = StringBuffer()..write("url(");
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $backslash) {
        buffer.write(escape());
      } else if (next == $percent ||
          next == $ampersand ||
          next == $hash ||
          (next >= $asterisk && next <= $tilde) ||
          next >= 0x0080) {
        buffer.writeCharCode(scanner.readChar());
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
    return identifier(normalize: true);
  }

  // ## Characters

  /// Consumes an escape sequence and returns the text that defines it.
  ///
  /// If [identifierStart] is true, this normalizes the escape sequence as
  /// though it were at the beginning of an identifier.
  @protected
  String escape({bool identifierStart = false}) {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    var start = scanner.position;
    scanner.expectChar($backslash);
    var value = 0;
    var first = scanner.peekChar();
    if (first == null) {
      scanner.error("Expected escape sequence.");
    } else if (isNewline(first)) {
      scanner.error("Expected escape sequence.");
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
      try {
        return String.fromCharCode(value);
      } on RangeError {
        scanner.error("Invalid Unicode code point.",
            position: start, length: scanner.position - start);
      }
    } else if (value <= 0x1F ||
        value == 0x7F ||
        (identifierStart && isDigit(value))) {
      var buffer = StringBuffer()..writeCharCode($backslash);
      if (value > 0xF) buffer.writeCharCode(hexCharFor(value >> 4));
      buffer.writeCharCode(hexCharFor(value & 0xF));
      buffer.writeCharCode($space);
      return buffer.toString();
    } else {
      return String.fromCharCodes([$backslash, value]);
    }
  }

  /// Consumes an escape sequence and returns the character it represents.
  @protected
  int escapeCharacter() => consumeEscapedCharacter(scanner);

  // Consumes the next character if it matches [condition].
  //
  // Returns whether or not the character was consumed.
  @protected
  bool scanCharIf(bool condition(int? character)) {
    var next = scanner.peekChar();
    if (!condition(next)) return false;
    scanner.readChar();
    return true;
  }

  /// Consumes the next character or escape sequence if it matches [expected].
  ///
  /// Matching will be case-insensitive unless [caseSensitive] is true.
  @protected
  bool scanIdentChar(int char, {bool caseSensitive = false}) {
    bool matches(int actual) => caseSensitive
        ? actual == char
        : characterEqualsIgnoreCase(char, actual);

    var next = scanner.peekChar();
    if (next != null && matches(next)) {
      scanner.readChar();
      return true;
    } else if (next == $backslash) {
      var start = scanner.state;
      if (matches(escapeCharacter())) return true;
      scanner.state = start;
    }
    return false;
  }

  /// Consumes the next character or escape sequence and asserts it matches
  /// [char].
  ///
  /// Matching will be case-insensitive unless [caseSensitive] is true.
  @protected
  void expectIdentChar(int letter, {bool caseSensitive = false}) {
    if (scanIdentChar(letter, caseSensitive: caseSensitive)) return;

    scanner.error('Expected "${String.fromCharCode(letter)}".',
        position: scanner.position);
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
  bool lookingAtIdentifier([int? forward]) {
    // See also [ScssParser._lookingAtInterpolatedIdentifier].

    forward ??= 0;
    var first = scanner.peekChar(forward);
    if (first == null) return false;
    if (isNameStart(first) || first == $backslash) return true;
    if (first != $dash) return false;

    var second = scanner.peekChar(forward + 1);
    if (second == null) return false;
    return isNameStart(second) || second == $backslash || second == $dash;
  }

  /// Returns whether the scanner is immediately before a sequence of characters
  /// that could be part of a plain CSS identifier body.
  @protected
  bool lookingAtIdentifierBody() {
    var next = scanner.peekChar();
    return next != null && (isName(next) || next == $backslash);
  }

  /// Consumes an identifier if its name exactly matches [text].
  @protected
  bool scanIdentifier(String text, {bool caseSensitive = false}) {
    if (!lookingAtIdentifier()) return false;

    var start = scanner.state;
    if (_consumeIdentifier(text, caseSensitive) && !lookingAtIdentifierBody()) {
      return true;
    } else {
      scanner.state = start;
      return false;
    }
  }

  /// Returns whether an identifier whose name exactly matches [text] is at the
  /// current scanner position.
  ///
  /// This doesn't move the scan pointer forward
  @protected
  bool matchesIdentifier(String text, {bool caseSensitive = false}) {
    if (!lookingAtIdentifier()) return false;

    var start = scanner.state;
    var result =
        _consumeIdentifier(text, caseSensitive) && !lookingAtIdentifierBody();
    scanner.state = start;
    return result;
  }

  /// Consumes [text] as an identifier, but doesn't verify whether there's
  /// additional identifier text afterwards.
  ///
  /// Returns `true` if the full [text] is consumed and `false` otherwise, but
  /// doesn't reset the scan pointer.
  bool _consumeIdentifier(String text, bool caseSensitive) {
    for (var letter in text.codeUnits) {
      if (!scanIdentChar(letter, caseSensitive: caseSensitive)) return false;
    }
    return true;
  }

  /// Consumes an identifier and asserts that its name exactly matches [text].
  @protected
  void expectIdentifier(String text,
      {String? name, bool caseSensitive = false}) {
    name ??= '"$text"';

    var start = scanner.position;
    for (var letter in text.codeUnits) {
      if (scanIdentChar(letter, caseSensitive: caseSensitive)) continue;
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

  /// Like [scanner.spanFrom], but passes the span through [_interpolationMap]
  /// if it's available.
  @protected
  FileSpan spanFrom(LineScannerState state) {
    var span = scanner.spanFrom(state);
    return _interpolationMap?.mapSpan(span) ?? span;
  }

  /// Prints a warning to standard error, associated with [span].
  @protected
  void warn(String message, FileSpan span) => logger.warn(message, span: span);

  /// Throws an error associated with [span].
  ///
  /// If [trace] is passed, attaches it as the error's stack trace.
  @protected
  Never error(String message, FileSpan span, [StackTrace? trace]) {
    var exception = StringScannerException(message, span, scanner.string);
    if (trace == null) {
      throw exception;
    } else {
      throwWithTrace(exception, trace);
    }
  }

  /// Runs callback and, if it throws a [SourceSpanFormatException], rethrows it
  /// with [message] as its message.
  @protected
  T withErrorMessage<T>(String message, T callback()) {
    try {
      return callback();
    } on SourceSpanFormatException catch (error, stackTrace) {
      throwWithTrace(
          SourceSpanFormatException(message, error.span, error.source),
          stackTrace);
    }
  }

  /// Prints a source span highlight of the current location being scanned.
  ///
  /// If [message] is passed, prints that as well. This is intended for use when
  /// debugging parser failures.
  @protected
  void debug([Object? message]) {
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
      try {
        return callback();
      } on SourceSpanFormatException catch (error, stackTrace) {
        var map = _interpolationMap;
        if (map == null) rethrow;

        throwWithTrace(map.mapException(error), stackTrace);
      }
    } on SourceSpanFormatException catch (error, stackTrace) {
      var span = error.span as FileSpan;
      if (startsWithIgnoreCase(error.message, "expected")) {
        span = _adjustExceptionSpan(span);
      }

      throwWithTrace(SassFormatException(error.message, span), stackTrace);
    } on MultiSourceSpanFormatException catch (error, stackTrace) {
      var span = error.span as FileSpan;
      var secondarySpans = error.secondarySpans.cast<FileSpan, String>();
      if (startsWithIgnoreCase(error.message, "expected")) {
        span = _adjustExceptionSpan(span);
        secondarySpans = {
          for (var entry in secondarySpans.entries)
            _adjustExceptionSpan(entry.key): entry.value
        };
      }

      throwWithTrace(
          MultiSpanSassFormatException(
              error.message, span, error.primaryLabel, secondarySpans),
          stackTrace);
    }
  }

  /// Moves span to [_firstNewlineBefore] if necessary.
  FileSpan _adjustExceptionSpan(FileSpan span) {
    if (span.length > 0) return span;

    var start = _firstNewlineBefore(span.start);
    return start == span.start ? span : start.pointSpan();
  }

  /// If [location] is separated from the previous non-whitespace character in
  /// `scanner.string` by one or more newlines, returns the location of the last
  /// separating newline.
  ///
  /// Otherwise returns [location].
  ///
  /// This helps avoid missing token errors pointing at the next closing bracket
  /// rather than the line where the problem actually occurred.
  FileLocation _firstNewlineBefore(FileLocation location) {
    var text = location.file.getText(0, location.offset);
    var index = location.offset - 1;
    int? lastNewline;
    while (index >= 0) {
      var codeUnit = text.codeUnitAt(index);
      if (!isWhitespace(codeUnit)) {
        return lastNewline == null
            ? location
            : location.file.location(lastNewline);
      }
      if (isNewline(codeUnit)) lastNewline = index;
      index--;
    }

    // If the document *only* contains whitespace before [location], always
    // return [location].
    return location;
  }
}
