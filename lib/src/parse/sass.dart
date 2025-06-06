// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../interpolation_buffer.dart';
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
  int? _nextIndentation;

  /// The beginning of the next source line after the scanner's position, or
  /// `null` if the next indentation hasn't been computed yet.
  ///
  /// A source line is any line that's not entirely whitespace.
  LineScannerState? _nextIndentationEnd;

  /// Whether the document is indented using spaces or tabs.
  ///
  /// If this is `true`, the document is indented using spaces. If it's `false`,
  /// the document is indented using tabs. If it's `null`, we haven't yet seen
  /// the indentation character used by the document.
  bool? _spaces;

  bool get indented => true;

  SassParser(super.contents, {super.url});

  Interpolation styleRuleSelector() {
    var start = scanner.state;

    var buffer = InterpolationBuffer();
    do {
      buffer.addInterpolation(almostAnyValue(omitComments: true));
      buffer.writeCharCode($lf);
    } while (buffer.trailingString.trimRight().endsWith(',') &&
        scanCharIf((char) => char.isNewline));

    return buffer.interpolation(scanner.spanFrom(start));
  }

  void expectStatementSeparator([String? name]) {
    var trailingSemicolon = _tryTrailingSemicolon();
    if (!atEndOfStatement()) {
      _expectNewline(trailingSemicolon: trailingSemicolon);
    }
    if (_peekIndentation() <= currentIndentation) return;
    scanner.error(
      "Nothing may be indented ${name == null ? 'here' : 'beneath a $name'}.",
      position: _nextIndentationEnd!.position,
    );
  }

  bool atEndOfStatement() => scanner.peekChar()?.isNewline ?? true;

  bool lookingAtChildren() =>
      atEndOfStatement() && _peekIndentation() > currentIndentation;

  Import importArgument() {
    switch (scanner.peekChar()) {
      case $u || $U:
        var start = scanner.state;
        if (scanIdentifier("url")) {
          if (scanner.scanChar($lparen)) {
            scanner.state = start;
            return super.importArgument();
          } else {
            scanner.state = start;
          }
        }

      case $single_quote || $double_quote:
        return super.importArgument();
    }

    var start = scanner.state;
    var next = scanner.peekChar();
    while (next != null &&
        next != $comma &&
        next != $semicolon &&
        !next.isNewline) {
      scanner.readChar();
      next = scanner.peekChar();
    }
    var url = scanner.substring(start.position);
    var span = scanner.spanFrom(start);

    if (isPlainImportUrl(url)) {
      // Serialize [url] as a Sass string because [StaticImport] expects it to
      // include quotes.
      return StaticImport(
        Interpolation.plain(SassString(url).toString(), span),
        span,
      );
    } else {
      try {
        return DynamicImport(parseImportUrl(url), span);
      } on FormatException catch (innerError, stackTrace) {
        error("Invalid URL: ${innerError.message}", span, stackTrace);
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
      if (_child(child) case var parsedChild?) children.add(parsedChild);
    });
    return children;
  }

  List<Statement> statements(Statement? statement()) {
    if (scanner.peekChar() case $tab || $space) {
      scanner.error(
        "Indenting at the beginning of the document is illegal.",
        position: 0,
        length: scanner.position,
      );
    }

    var statements = <Statement>[];
    while (!scanner.isDone) {
      if (_child(statement) case var child?) statements.add(child);
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
  Statement? _child(Statement? child()) => switch (scanner.peekChar()) {
        // Ignore empty lines.
        $cr || $lf || $ff => null,
        $dollar => variableDeclarationWithoutNamespace(),
        $slash => switch (scanner.peekChar(1)) {
            $slash => _silentComment(),
            $asterisk => _loudComment(),
            _ => child(),
          },
        _ => child(),
      };

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

        while (!scanner.isDone && !scanner.peekChar().isNewline) {
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

    return lastSilentComment = SilentComment(
      buffer.toString(),
      scanner.spanFrom(start),
    );
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
        if (scanner.peekChar().isNewline) {
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
        switch (scanner.peekChar()) {
          case $lf || $cr || $ff:
            break loop;

          case $hash:
            if (scanner.peekChar(1) == $lbrace) {
              var (expression, span) = singleInterpolation();
              buffer.add(expression, span);
            } else {
              buffer.writeCharCode(scanner.readChar());
            }

          case $asterisk:
            if (scanner.peekChar(1) == $slash) {
              buffer.writeCharCode(scanner.readChar());
              buffer.writeCharCode(scanner.readChar());
              var span = scanner.spanFrom(start);
              whitespace(consumeNewlines: false);

              // For backwards compatibility, allow additional comments after
              // the initial comment is closed.
              while (scanner.peekChar().isNewline &&
                  _peekIndentation() > parentIndentation) {
                while (_lookingAtDoubleNewline()) {
                  _expectNewline();
                }
                _readIndentation();
                whitespace(consumeNewlines: false);
              }

              if (!scanner.isDone && !scanner.peekChar().isNewline) {
                var errorStart = scanner.state;
                while (!scanner.isDone && !scanner.peekChar().isNewline) {
                  scanner.readChar();
                }
                throw MultiSpanSassFormatException(
                  "Unexpected text after end of comment",
                  scanner.spanFrom(errorStart),
                  "extra text",
                  {span: "comment"},
                );
              } else {
                return LoudComment(buffer.interpolation(span));
              }
            } else {
              buffer.writeCharCode(scanner.readChar());
            }

          case _:
            buffer.writeCharCode(scanner.readChar());
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

    return LoudComment(buffer.interpolation(scanner.spanFrom(start)));
  }

  void whitespaceWithoutComments({required bool consumeNewlines}) {
    // This overrides whitespace consumption to only consume newlines when
    // `consumeNewlines` is true.
    while (!scanner.isDone) {
      var next = scanner.peekChar();
      if (consumeNewlines ? !next.isWhitespace : !next.isSpaceOrTab) break;
      scanner.readChar();
    }
  }

  /// Expect and consume a single newline character.
  ///
  /// If [trailingSemicolon] is true, this follows a semicolon, which is used
  /// for error reporting.
  void _expectNewline({bool trailingSemicolon = false}) {
    switch (scanner.peekChar()) {
      case $cr:
        scanner.readChar();
        if (scanner.peekChar() == $lf) scanner.readChar();
        return;
      case $lf || $ff:
        scanner.readChar();
        return;
      default:
        scanner.error(
          trailingSemicolon
              ? "multiple statements on one line are not supported in the indented syntax."
              : "expected newline.",
        );
    }
  }

  /// Returns whether the scanner is immediately before *two* newlines.
  bool _lookingAtDoubleNewline() => switch (scanner.peekChar()) {
        $cr => switch (scanner.peekChar(1)) {
            $lf => scanner.peekChar(2).isNewline,
            $cr || $ff => true,
            _ => false,
          },
        $lf || $ff => scanner.peekChar(1).isNewline,
        _ => false,
      };

  /// As long as the scanner's position is indented beneath the starting line,
  /// runs [body] to consume the next statement.
  void _whileIndentedLower(void body()) {
    var parentIndentation = currentIndentation;
    int? childIndentation;
    while (_peekIndentation() > parentIndentation) {
      var indentation = _readIndentation();
      childIndentation ??= indentation;
      if (childIndentation != indentation) {
        scanner.error(
          "Inconsistent indentation, expected $childIndentation spaces.",
          position: scanner.position - scanner.column,
          length: scanner.column,
        );
      }

      body();
    }
  }

  /// Consumes indentation whitespace and returns the indentation level of the
  /// next line.
  int _readIndentation() {
    var currentIndentation =
        _currentIndentation = _nextIndentation ??= _peekIndentation();
    scanner.state = _nextIndentationEnd!;
    _nextIndentation = null;
    _nextIndentationEnd = null;
    return currentIndentation;
  }

  /// Returns the indentation level of the next line.
  int _peekIndentation() {
    if (_nextIndentation case var cached?) return cached;

    if (scanner.isDone) {
      _nextIndentation = 0;
      _nextIndentationEnd = scanner.state;
      return 0;
    }

    var start = scanner.state;
    if (!scanCharIf((char) => char.isNewline)) {
      scanner.error("Expected newline.", position: scanner.position);
    }

    late bool containsTab;
    late bool containsSpace;
    late int nextIndentation;
    do {
      containsTab = false;
      containsSpace = false;
      nextIndentation = 0;

      loop:
      while (true) {
        switch (scanner.peekChar()) {
          case $space:
            containsSpace = true;
          case $tab:
            containsTab = true;
          case _:
            break loop;
        }
        nextIndentation++;
        scanner.readChar();
      }

      if (scanner.isDone) {
        _nextIndentation = 0;
        _nextIndentationEnd = scanner.state;
        scanner.state = start;
        return 0;
      }
    } while (scanCharIf((char) => char.isNewline));

    _checkIndentationConsistency(containsTab, containsSpace);

    _nextIndentation = nextIndentation;
    if (nextIndentation > 0) _spaces ??= containsSpace;
    _nextIndentationEnd = scanner.state;
    scanner.state = start;
    return nextIndentation;
  }

  /// Ensures that the document uses consistent characters for indentation.
  ///
  /// The [containsTab] and [containsSpace] parameters refer to a single line of
  /// indentation that has just been parsed.
  void _checkIndentationConsistency(bool containsTab, bool containsSpace) {
    if (containsTab) {
      if (containsSpace) {
        scanner.error(
          "Tabs and spaces may not be mixed.",
          position: scanner.position - scanner.column,
          length: scanner.column,
        );
      } else if (_spaces == true) {
        scanner.error(
          "Expected spaces, was tabs.",
          position: scanner.position - scanner.column,
          length: scanner.column,
        );
      }
    } else if (containsSpace && _spaces == false) {
      scanner.error(
        "Expected tabs, was spaces.",
        position: scanner.position - scanner.column,
        length: scanner.column,
      );
    }
  }

  /// Consumes a semicolon and trailing whitespace, including comments.
  ///
  /// Returns whether a semicolon was consumed.
  bool _tryTrailingSemicolon() {
    if (scanCharIf((char) => char == $semicolon)) {
      whitespace(consumeNewlines: false);
      return true;
    }
    return false;
  }
}
