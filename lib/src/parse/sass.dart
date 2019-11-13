// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/sass.dart';
import '../interpolation_buffer.dart';
import '../logger.dart';
import '../util/character.dart';
import '../value.dart';
import 'stylesheet.dart';

/// A parser for the indented syntax.
class SassParser extends StylesheetParser {
  int get currentIndentation => _currentIndentation;
  var _currentIndentation = 0;

  /// The indentation level of the next source line after the scanner's
  /// position, or `null` if that hasn't been computed yet.
  ///
  /// A source line is any line that's not entirely whitespace.
  int _nextIndentation;

  /// The beginning of the next source line after the scanner's position, or
  /// `null` if that hasn't been computed yet.
  ///
  /// A source line is any line that's not entirely whitespace.
  LineScannerState _nextIndentationEnd;

  /// Whether the document is indented using spaces or tabs.
  ///
  /// If this is `true`, the document is indented using spaces. If it's `false`,
  /// the document is indented using tabs. If it's `null`, we haven't yet seen
  /// the indentation character used by the document.
  bool _spaces;

  bool get indented => true;

  SassParser(String contents, {Object url, Logger logger})
      : super(contents, url: url, logger: logger);

  Interpolation styleRuleSelector() {
    var start = scanner.state;

    var buffer = InterpolationBuffer();
    do {
      buffer.addInterpolation(almostAnyValue());
      buffer.writeCharCode($lf);
    } while (buffer.trailingString.trimRight().endsWith(",") &&
        scanCharIf(isNewline));

    return buffer.interpolation(scanner.spanFrom(start));
  }

  void expectStatementSeparator([String name]) {
    if (!atEndOfStatement()) _expectNewline();
    if (_peekIndentation() <= currentIndentation) return;
    scanner.error(
        "Nothing may be indented ${name == null ? 'here' : 'beneath a $name'}.",
        position: _nextIndentationEnd.position);
  }

  bool atEndOfStatement() {
    var next = scanner.peekChar();
    return next == null || isNewline(next);
  }

  bool lookingAtChildren() =>
      atEndOfStatement() && _peekIndentation() > currentIndentation;

  Import importArgument() {
    switch (scanner.peekChar()) {
      case $u:
      case $U:
        var start = scanner.state;
        if (scanIdentifier("url")) {
          if (scanner.scanChar($lparen)) {
            scanner.state = start;
            return super.importArgument();
          } else {
            scanner.state = start;
          }
        }
        break;

      case $single_quote:
      case $double_quote:
        return super.importArgument();
    }

    var start = scanner.state;
    var next = scanner.peekChar();
    while (next != null &&
        next != $comma &&
        next != $semicolon &&
        !isNewline(next)) {
      scanner.readChar();
      next = scanner.peekChar();
    }
    var url = scanner.substring(start.position);
    var span = scanner.spanFrom(start);

    if (isPlainImportUrl(url)) {
      // Serialize [url] as a Sass string because [StaticImport] expects it to
      // include quotes.
      return StaticImport(
          Interpolation([SassString(url).toString()], span), span);
    } else {
      try {
        return DynamicImport(parseImportUrl(url), span);
      } on FormatException catch (innerError) {
        error("Invalid URL: ${innerError.message}", span);
      }
    }
  }

  bool scanElse(int ifIndentation) {
    if (_peekIndentation() != ifIndentation) return false;
    var start = scanner.state;
    var startIndentation = currentIndentation;
    var startNextIndentation = _nextIndentation;
    var startNextIndentationEnd = _nextIndentationEnd;

    _readIndentation();
    if (scanner.scanChar($at) && scanIdentifier('else')) return true;

    scanner.state = start;
    _currentIndentation = startIndentation;
    _nextIndentation = startNextIndentation;
    _nextIndentationEnd = startNextIndentationEnd;
    return false;
  }

  List<Statement> children(Statement child()) {
    var children = <Statement>[];
    _whileIndentedLower(() {
      children.add(_child(child));
    });
    return children;
  }

  List<Statement> statements(Statement statement()) {
    var first = scanner.peekChar();
    if (first == $tab || first == $space) {
      scanner.error("Indenting at the beginning of the document is illegal.",
          position: 0, length: scanner.position);
    }

    var statements = <Statement>[];
    while (!scanner.isDone) {
      var child = _child(statement);
      if (child != null) statements.add(child);
      var indentation = _readIndentation();
      assert(indentation == 0);
    }
    return statements;
  }

  /// Consumes a child of the current statement.
  ///
  /// This consumes children that are allowed at all levels of the document; the
  /// [child] parameter is called to consume any children that are specifically
  /// allowed in the caller's context.
  Statement _child(Statement child()) {
    switch (scanner.peekChar()) {
      // Ignore empty lines.
      case $cr:
      case $lf:
      case $ff:
        return null;

      case $dollar:
        return variableDeclarationWithoutNamespace();
        break;

      case $slash:
        switch (scanner.peekChar(1)) {
          case $slash:
            return _silentComment();
            break;
          case $asterisk:
            return _loudComment();
            break;
          default:
            return child();
            break;
        }
        break;

      default:
        return child();
        break;
    }
  }

  /// Consumes an indented-style silent comment.
  SilentComment _silentComment() {
    var start = scanner.state;
    scanner.expect("//");
    var buffer = StringBuffer();
    var parentIndentation = currentIndentation;

    outer:
    do {
      var commentPrefix = scanner.scanChar($slash) ? "///" : "//";

      while (true) {
        buffer.write(commentPrefix);

        // Skip the initial characters because we're already writing the
        // slashes.
        for (var i = commentPrefix.length;
            i < currentIndentation - parentIndentation;
            i++) {
          buffer.writeCharCode($space);
        }

        while (!scanner.isDone && !isNewline(scanner.peekChar())) {
          buffer.writeCharCode(scanner.readChar());
        }
        buffer.writeln();

        if (_peekIndentation() < parentIndentation) break outer;

        if (_peekIndentation() == parentIndentation) {
          // Look ahead to the next line to see if it starts another comment.
          if (scanner.peekChar(1 + parentIndentation) == $slash &&
              scanner.peekChar(2 + parentIndentation) == $slash) {
            _readIndentation();
          }
          break;
        }
        _readIndentation();
      }
    } while (scanner.scan("//"));

    lastSilentComment =
        SilentComment(buffer.toString(), scanner.spanFrom(start));
    return lastSilentComment;
  }

  /// Consumes an indented-style loud context.
  LoudComment _loudComment() {
    var start = scanner.state;
    scanner.expect("/*");

    var first = true;
    var buffer = InterpolationBuffer()..write("/*");
    var parentIndentation = currentIndentation;
    while (true) {
      if (first) {
        // If the first line is empty, ignore it.
        var beginningOfComment = scanner.position;
        spaces();
        if (isNewline(scanner.peekChar())) {
          _readIndentation();
          buffer.writeCharCode($space);
        } else {
          buffer.write(scanner.substring(beginningOfComment));
        }
      } else {
        buffer.writeln();
        buffer.write(" * ");
      }
      first = false;

      for (var i = 3; i < currentIndentation - parentIndentation; i++) {
        buffer.writeCharCode($space);
      }

      loop:
      while (!scanner.isDone) {
        var next = scanner.peekChar();
        switch (next) {
          case $lf:
          case $cr:
          case $ff:
            break loop;

          case $hash:
            if (scanner.peekChar(1) == $lbrace) {
              buffer.add(singleInterpolation());
            } else {
              buffer.writeCharCode(scanner.readChar());
            }
            break;

          default:
            buffer.writeCharCode(scanner.readChar());
            break;
        }
      }

      if (_peekIndentation() <= parentIndentation) break;

      // Preserve empty lines.
      while (_lookingAtDoubleNewline()) {
        _expectNewline();
        buffer.writeln();
        buffer.write(" *");
      }

      _readIndentation();
    }
    if (!buffer.trailingString.trimRight().endsWith("*/")) buffer.write(" */");

    return LoudComment(buffer.interpolation(scanner.spanFrom(start)));
  }

  void whitespaceWithoutComments() {
    // This overrides whitespace consumption so that it doesn't consume
    // newlines.
    while (!scanner.isDone) {
      var next = scanner.peekChar();
      if (next != $tab && next != $space) break;
      scanner.readChar();
    }
  }

  void loudComment() {
    // This overrides loud comment consumption so that it doesn't consume
    // multi-line comments.
    scanner.expect("/*");
    while (true) {
      var next = scanner.readChar();
      if (isNewline(next)) scanner.error("expected */.");
      if (next != $asterisk) continue;

      do {
        next = scanner.readChar();
      } while (next == $asterisk);
      if (next == $slash) break;
    }
  }

  /// Expect and consume a single newline character.
  void _expectNewline() {
    switch (scanner.peekChar()) {
      case $semicolon:
        scanner.error("semicolons aren't allowed in the indented syntax.");
        return;
      case $cr:
        scanner.readChar();
        if (scanner.peekChar() == $lf) scanner.readChar();
        return;
      case $lf:
      case $ff:
        scanner.readChar();
        return;
      default:
        scanner.error("expected newline.");
    }
  }

  /// Returns whether the scanner is immediately before *two* newlines.
  bool _lookingAtDoubleNewline() {
    switch (scanner.peekChar()) {
      case $cr:
        var nextChar = scanner.peekChar(1);
        if (nextChar == $lf) return isNewline(scanner.peekChar(2));
        return nextChar == $cr || nextChar == $ff;
      case $lf:
      case $ff:
        return isNewline(scanner.peekChar(1));
      default:
        return false;
    }
  }

  /// As long as the scanner's position is indented beneath the starting line,
  /// runs [body] to consume the next statement.
  void _whileIndentedLower(void body()) {
    var parentIndentation = currentIndentation;
    int childIndentation;
    while (_peekIndentation() > parentIndentation) {
      var indentation = _readIndentation();
      childIndentation ??= indentation;
      if (childIndentation != indentation) {
        scanner.error(
            "Inconsistent indentation, expected $childIndentation spaces.",
            position: scanner.position - scanner.column,
            length: scanner.column);
      }

      body();
    }
  }

  /// Consumes indentation whitespace and returns the indentation level of the
  /// next line.
  int _readIndentation() {
    if (_nextIndentation == null) _peekIndentation();
    _currentIndentation = _nextIndentation;
    scanner.state = _nextIndentationEnd;
    _nextIndentation = null;
    _nextIndentationEnd = null;
    return currentIndentation;
  }

  /// Returns the indentation level of the next line.
  int _peekIndentation() {
    if (_nextIndentation != null) return _nextIndentation;

    if (scanner.isDone) {
      _nextIndentation = 0;
      _nextIndentationEnd = scanner.state;
      return 0;
    }

    var start = scanner.state;
    if (!scanCharIf(isNewline)) {
      scanner.error("Expected newline.", position: scanner.position);
    }

    bool containsTab;
    bool containsSpace;
    do {
      containsTab = false;
      containsSpace = false;
      _nextIndentation = 0;

      while (true) {
        var next = scanner.peekChar();
        if (next == $space) {
          containsSpace = true;
        } else if (next == $tab) {
          containsTab = true;
        } else {
          break;
        }
        _nextIndentation++;
        scanner.readChar();
      }

      if (scanner.isDone) {
        _nextIndentation = 0;
        _nextIndentationEnd = scanner.state;
        scanner.state = start;
        return 0;
      }
    } while (scanCharIf(isNewline));

    _checkIndentationConsistency(containsTab, containsSpace);

    if (_nextIndentation > 0) _spaces ??= containsSpace;
    _nextIndentationEnd = scanner.state;
    scanner.state = start;
    return _nextIndentation;
  }

  /// Ensures that the document uses consistent characters for indentation.
  ///
  /// The [containsTab] and [containsSpace] parameters refer to a single line of
  /// indentation that has just been parsed.
  void _checkIndentationConsistency(bool containsTab, bool containsSpace) {
    if (containsTab) {
      if (containsSpace) {
        scanner.error("Tabs and spaces may not be mixed.",
            position: scanner.position - scanner.column,
            length: scanner.column);
      } else if (_spaces == true) {
        scanner.error("Expected spaces, was tabs.",
            position: scanner.position - scanner.column,
            length: scanner.column);
      }
    } else if (containsSpace && _spaces == false) {
      scanner.error("Expected tabs, was spaces.",
          position: scanner.position - scanner.column, length: scanner.column);
    }
  }
}
