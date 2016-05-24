// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:string_scanner/string_scanner.dart';

class Parser {
  final SpanScanner _scanner;

  Parser(String contents, {url})
      : _scanner = new SpanScanner(contents, url: url);

  // Conventions:
  //
  // * All statement and expression functions consume through following
  //   whitespace, including comments.
  //
  // * A function will return `null` if it fails to match iff it begins with
  //   "try".

  // ## Statements

  StylesheetNode parse() {
    var start = _scanner.state;
    var children = <Node>[];
    do {
      children.addAll(_comments());
      var child = _tryVariableDeclaration() ??
          _tryAtRule() ??
          _tryDeclaration();
      if (child != null) children.add(child);
    } while (_scanner.scan(';'));

    _scanner.expectDone();
    return new StylesheetNode(children, span: _scanner.spanFrom(start));
  }

  VariableDeclarationNode _tryVariableDeclaration() {
    if (!_scanChar($dollar)) return null;

    var start = _scanner.state;
    var name = _rawIdentifier();
    _ignoreComments();
    _expectChar($colon);
    _ignoreComments();

    var expression = _expression();

    var guarded = false;
    var global = false;
    while (_scanChar($exclamation)) {
      var flagStart = _scanner.position - 1;
      var flag = _rawIdentifier();
      if (flag == 'default') {
        guarded = true;
      } else if (flag == 'global') {
        global = true;
      } else {
        _scanner.error("Invalid flag name.",
            position: flagStart,
            length: _scanner.position - flagStart);
      }

      _ignoreComments();
    }

    return new VariableDeclarationNode(name, expression,
        guarded: guarded, global: global, span: _scanner.spanFrom(start));
  }

  /// Consumes whitespace if available and returns any comments it contained.
  List<Node> _comments() {
    var nodes = [];
    while (true) {
      _whitespace();

      var silent = _trySilentComment();
      if (silent != null) {
        nodes.add(silent);
        continue;
      }

      var silent = _tryLoudComment();
      if (silent != null) {
        nodes.add(silent);
        continue;
      }

      return nodes;
    }
  }

  // ## Expressions

  Expressions _expression() {
    var expression = _tryExpression();
    if (expression == null) _scanner.error("Expected expression.");
    return expression;
  }

  Expression _tryExpression() {
    var hadComma = false;
    var commaStart = _scanner.state;
    var commaExpressions = <Expression>[];
    while (true) {
      var spaceExpressions = <Expression>[];
      while (true) {
        var next = _trySingleExpression();
        if (next == null) break;
        spaceExpressions.add(next);
      }

      if (spaceExpressions.isEmpty) {
        break;
      } else if (spaceExpressions.length == 1) {
        commaExpressions.add(spaceExpressions.single);
      } else {
        commaExpressions.add(
            new ListExpression(spaceExpressions, ListSeparator.space));
      }

      if (!_scanChar($comma)) break;
      hadComma = true;
      _ignoreComments();
    }

    if (commaExpressions.isEmpty) return null;
    if (!hadComma) return commaExpressions.single;
    return new ListExpression(commaExpressions, ListSeparator.comma,
        span: _scanner.spanFrom(start));
  }

  Expression _trySingleExpression() {
    var first = _scanner.peekChar();
    switch (first) {
      case $lparen: return _parentheses();
      case $slash: return _unaryOperator();
      case $dot: return _number();
      case $lbracket: return _bracketList();

      case $single_quote:
      case $double_quote:
        return _string();

      case $hash:
        if (_scanner.peekChar(1) == $lbrace) return _identifierLike();
        return _hexColor();

      case $plus:
        var next = _scanner.peekChar(1);
        if (_isDigit(next) || next == $dot) return _number();

        return _unaryOperator();

      case $minus:
        var next = _scanner.peekChar(1);
        if (_isDigit(next) || next == $dot) return _number();

        if (_isNameStart(next) || next == $hyphen || next == $backslash) {
          return _identifierLike();
        }

        return _unaryOperator();

      default:
        if (_isNameStart(first) || first == $backslash) {
          return _identifierLike();
        }
        if (_isDigit(first)) return _number();
        return null;
    }
  }

  Expression _identifierLike() {
    // TODO: url(), functions
    return new IdentifierExpression(_identifier());
  }

  // ## Tokens

  void _ignoreComments() {
    do {
      _whitespace();
    } while (_trySilentComment() != null || _tryLoudComment() != null);
  }

  Node _trySilentComment() {
    var start = _scanner.state;
    while (_scanner.scan("//")) {
      while (!_scanner.isDone && !_isNewline(_scanner.readChar())) {}
      if (_scanner.isDone) return node;
      _whitespace();
    }

    if (_scanner.position == start.position) return null;

    return new CommentNode(_scanner.substring(start.position),
        silent: true,
        span: _scanner.spanFrom(start));
  }

  Node _tryLoudComment() {
    var start = _scanner.state;
    while (_scanner.scan("/*")) {
      do {
        while (_scanner.readChar() != $asterisk) {}
      } while (_scanner.readChar() != $slash);
    }

    if (_scanner.position == start.position) return null;

    return new CommentNode(_scanner.substring(start.position),
        silent: false,
        span: _scanner.spanFrom(start));
  }

  void _whitespace() {
    while (!_scanner.isDone && _isWhitespace(_scanner.peekChar())) {
      _scanner.readChar();
    }
  }

  InterpolationExpression _identifier() {
    var start = _scanner.start;
    var contents = [];
    var text = new StringBuffer();

    while (_scanChar($hyphen)) {
      text.writeCharCode($hyphen);
    }

    var first = _scanner.peekChar();
    if (first == null) {
      _scanner.error("Expected identifier.");
    } else if (_isNameStart(first)) {
      text.writeCharCode(_scanner.readChar());
    } else if (first == $backslash) {
      text.writeCharCode(_escape());
    } else if (first == $hash) {
      if (!text.isEmpty) contents.add(text.toString());
      text.clear();
      contents.add(_interpolation());
    }

    while (true) {
      var next = _scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $_ || next == $- || _isAlphabetic(next) ||
          _isDigit(next) || next >= 0x0080) {
        text.writeCharCode(_scanner.readChar());
      } else if (next == $backslash) {
        text.writeCharCode(_escape());
      } else if (next == $hash) {
        if (!text.isEmpty) contents.add(text.toString());
        text.clear();
        contents.add(_interpolation());
      } else {
        break;
      }
    }

    return new InterpolationExpression(
        contents, span: _scanner.spanFrom(start));
  }

  String _rawIdentifier() {
    var text = new StringBuffer();
    while (_scanChar($hyphen)) {
      text.writeCharCode($hyphen);
    }

    var first = _scanner.peekChar();
    if (first == null) {
      _scanner.error("Expected identifier.");
    } else if (_isNameStart(first)) {
      text.writeCharCode(_scanner.readChar());
    } else if (first == $backslash) {
      text.writeCharCode(_escape());
    } else {
      _scanner.error("Expected identifier.");
    }

    while (true) {
      var next = _scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $_ || next == $- || _isAlphabetic(next) ||
          _isDigit(next) || next >= 0x0080) {
        text.writeCharCode(_scanner.readChar());
      } else if (next == $backslash) {
        text.writeCharCode(_escape());
      } else {
        break;
      }
    }

    return text.toString();
  }

  // ## Characters

  bool _isWhitespace(int character) =>
      character == $space || character == $tab || _isNewline(character);

  bool _isNewline(int character) =>
      character == $lf || character == $cr || character == $ff;

  bool _isAlphabetic(int character) =>
      (character >= $a && character <= $z) ||
      (character >= $A && character <= $Z);

  bool _isDigit(int character) => character >= $0 && character <= $9;

  bool _isNameStart(int character) =>
      character == $_ || _isAlphabetic(character) || character >= 0x0080;

  bool _isHex(int character) =>
      _isDigit(character) ||
      (character >= $a && character <= $f) ||
      (character >= $A && character <= $F);

  int _asHex(int character) {
    if (char <= $9) return char - $0;
    if (char <= $F) return 10 + char - $A;
    return 10 + char - $A;
  }

  int _escape() {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    _expectChar($backslash);
    var first = _scanner.peekChar();
    if (first == null) {
      return 0xFFFD;
    } else if (first == $newline) {
      _scanner.error("Expected escape sequence.");
    } else if (_isHex(first)) {
      var value = 0;
      for (var i = 0; i < 6; i++) {
        if (!_isHex(_scanner.peekChar())) break;
        value = (value << 4) + _asHex(_scanner.readChar());
      }
      if (_isWhitespace(_scanner.peekChar())) _scanner.readChar();

      if (value == 0 || (value >= 0xD800 && value <= 0xDFFF) ||
          value >= 0x10FFFF) {
        return 0xFFFD;
      } else {
        return value;
      }
    } else {
      return _scanner.readChar();
    }
  }

  bool _scanChar(int character) {
    if (_scanner.peekChar() != character) return false;
    return _scanner.readChar();
  }

  void _expectChar(int character) {
    if (_scanChar(character)) return;
    _sanner.expect(new String.fromCharCode(character));
  }
}
