// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import 'ast/node.dart';
import 'ast/comment.dart';
import 'ast/expression.dart';
import 'ast/expression/identifier.dart';
import 'ast/expression/interpolation.dart';
import 'ast/expression/list.dart';
import 'ast/stylesheet.dart';
import 'ast/variable_declaration.dart';

class Parser {
  final SpanScanner _scanner;

  Parser(String contents, {url})
      : _scanner = new SpanScanner(contents, sourceUrl: url);

  // Conventions:
  //
  // * All statement functions consume through following whitespace, including
  //   comments. No other functions do so unless explicitly specified.
  //
  // * A function will return `null` if it fails to match iff it begins with
  //   "try".

  // ## Statements

  StylesheetNode parse() {
    var start = _scanner.state;
    var children = <AstNode>[];
    do {
      children.addAll(_comments());
      switch (_scanner.peekChar()) {
        case $dollar:
          children.add(_variableDeclaration());
          break;

        case $at:
          children.add(_atRule());
          break;

        case $semicolon: break;

        default:
          children.add(_declaration());
          break;
      }
    } while (_scanner.scan(';'));

    _scanner.expectDone();
    return new StylesheetNode(children, span: _scanner.spanFrom(start));
  }

  VariableDeclarationNode _variableDeclaration() {
    if (!_scanChar($dollar)) return null;

    var start = _scanner.state;
    var name = _identifier();
    _ignoreComments();
    _expectChar($colon);
    _ignoreComments();

    var expression = _expression();

    var guarded = false;
    var global = false;
    while (_scanChar($exclamation)) {
      var flagStart = _scanner.position - 1;
      var flag = _identifier();
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

  AstNode _atRule() => throw new UnimplementedError();

  AstNode _declaration() => throw new UnimplementedError();

  /// Consumes whitespace if available and returns any comments it contained.
  List<CommentNode> _comments() {
    var nodes = <CommentNode>[];
    while (true) {
      _whitespace();

      var silent = _trySilentComment();
      if (silent != null) {
        nodes.add(silent);
        continue;
      }

      var loud = _tryLoudComment();
      if (loud != null) {
        nodes.add(loud);
        continue;
      }

      return nodes;
    }
  }

  // ## Expressions

  Expression _expression() {
    var expression = _tryExpression();
    if (expression == null) _scanner.error("Expected expression.");
    return expression;
  }

  Expression _tryExpression() {
    var hadComma = false;
    var start = _scanner.state;
    var commaExpressions = <Expression>[];
    while (true) {
      var spaceExpressions = <Expression>[];
      while (true) {
        var next = _trySingleExpression();
        if (next == null) break;
        spaceExpressions.add(next);
        _ignoreComments();
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

        if (_isNameStart(next) || next == $dash || next == $backslash) {
          return _identifierLike();
        }

        return _unaryOperator();

      default:
        if (first == null) return null;

        if (_isNameStart(first) || first == $backslash) {
          return _identifierLike();
        }
        if (_isDigit(first)) return _number();
        return null;
    }
  }

  Expression _parentheses() => throw new UnimplementedError();
  Expression _unaryOperator() => throw new UnimplementedError();
  Expression _number() => throw new UnimplementedError();
  Expression _bracketList() => throw new UnimplementedError();
  Expression _string() => throw new UnimplementedError();
  Expression _hexColor() => throw new UnimplementedError();

  Expression _identifierLike() {
    // TODO: url(), functions
    return new IdentifierExpression(_interpolatedIdentifier());
  }

  InterpolationExpression _interpolatedIdentifier() {
    var start = _scanner.state;
    var contents = [];
    var text = new StringBuffer();

    while (_scanChar($dash)) {
      text.writeCharCode($dash);
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
      contents.add(_singleInterpolation());
    }

    while (true) {
      var next = _scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $underscore || next == $dash ||
          _isAlphabetic(next) || _isDigit(next) || next >= 0x0080) {
        text.writeCharCode(_scanner.readChar());
      } else if (next == $backslash) {
        text.writeCharCode(_escape());
      } else if (next == $hash) {
        if (!text.isEmpty) contents.add(text.toString());
        text.clear();
        contents.add(_singleInterpolation());
      } else {
        break;
      }
    }

    if (!text.isEmpty) contents.add(text.toString());
    return new InterpolationExpression(
        contents, span: _scanner.spanFrom(start));
  }

  Expression _singleInterpolation() {
    _scanner.expect('#{');
    var expression = _expression();
    _expectChar($rbrace);
    return expression;
  }

  // ## Tokens

  void _ignoreComments() {
    do {
      _whitespace();
    } while (_trySilentComment() != null || _tryLoudComment() != null);
  }

  CommentNode _trySilentComment() {
    var start = _scanner.state;
    while (_scanner.scan("//")) {
      while (!_scanner.isDone && !_isNewline(_scanner.readChar())) {}
      if (_scanner.isDone) break;
      _whitespace();
    }

    if (_scanner.position == start.position) return null;

    return new CommentNode(_scanner.substring(start.position),
        silent: true,
        span: _scanner.spanFrom(start));
  }

  CommentNode _tryLoudComment() {
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

  String _identifier() {
    var text = new StringBuffer();
    while (_scanChar($dash)) {
      text.writeCharCode($dash);
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
      } else if (next == $underscore || next == $dash ||
          _isAlphabetic(next) || _isDigit(next) || next >= 0x0080) {
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
    if (character <= $9) return character - $0;
    if (character <= $F) return 10 + character - $A;
    return 10 + character - $A;
  }

  int _escape() {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    _expectChar($backslash);
    var first = _scanner.peekChar();
    if (first == null) {
      return 0xFFFD;
    } else if (first == $lf) {
      _scanner.error("Expected escape sequence.");
      return 0;
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
    _scanner.readChar();
    return true;
  }

  void _expectChar(int character) {
    if (_scanChar(character)) return;
    _scanner.expect(new String.fromCharCode(character));
  }
}
