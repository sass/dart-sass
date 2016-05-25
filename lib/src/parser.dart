// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import 'ast/sass/expression.dart';
import 'ast/sass/statement.dart';
import 'interpolation_buffer.dart';
import 'value/list.dart';

class Parser {
  final SpanScanner _scanner;

  Parser(String contents, {url})
      : _scanner = new SpanScanner(contents, sourceUrl: url);

  // Conventions:
  //
  // * All statement functions consume through following whitespace, including
  //   comments. No other functions do so unless explicitly specified.

  // ## Statements

  Stylesheet parse() {
    var start = _scanner.state;
    var children = <Statement>[];
    while (true) {
      children.addAll(_comments());
      if (_scanner.isDone) break;
      switch (_scanner.peekChar()) {
        case $dollar:
          children.add(_variableDeclaration());
          break;

        case $at:
          children.add(_atRule());
          break;

        case $semicolon:
          _scanner.readChar();
          break;

        default:
          children.add(_styleRule());
          break;
      }
    }

    _scanner.expectDone();
    return new Stylesheet(children, span: _scanner.spanFrom(start));
  }

  VariableDeclaration _variableDeclaration() {
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

    return new VariableDeclaration(name, expression,
        guarded: guarded, global: global, span: _scanner.spanFrom(start));
  }

  Statement _atRule() => throw new UnimplementedError();

  StyleRule _styleRule() {
    var start = _scanner.state;
    var selector = _almostAnyValue();
    var children = _styleRuleChildren();
    return new StyleRule(selector, children,
        span: _scanner.spanFrom(start));
  }

  List<Statement> _styleRuleChildren() {
    _expectChar($lbrace);
    var children = <Statement>[];
    loop: while (true) {
      children.addAll(_comments());
      switch (_scanner.peekChar()) {
        case $dollar:
          children.add(_variableDeclaration());
          break;

        case $at:
          children.add(_atRule());
          break;

        case $semicolon:
          _scanner.readChar();
          break;

        case $rbrace:
          break loop;

        default:
          children.add(_declarationOrStyleRule());
          break;
      }
    }

    children.addAll(_comments());
    _expectChar($rbrace);
    return children;
  }

  Expression _declarationValue() {
    if (_scanner.peekChar() == $lbrace) {
      return new StringExpression(
          new InterpolationExpression([], span: _scanner.emptySpan));
    }

    // TODO: parse static values specially?
    return _expression();
  }

  Statement _customPropertyDeclaration(InterpolationExpression name) =>
      throw new UnimplementedError();

  /// Parses a [Declaration] or a [StyleRule].
  ///
  /// When parsing the contents of a style rule, it can be difficult to tell
  /// declarations apart from nested style rules. Since we don't thoroughly
  /// parse selectors until after resolving interpolation, we can share a bunch
  /// of the parsing of the two, but we need to disambiguate them first. We use
  /// the following criteria:
  ///
  /// * If the entity doesn't start with an identifier followed by a colon,
  ///   it's a selector. There are some additional mostly-unimportant cases
  ///   here to support various declaration hacks.
  ///
  /// * If the colon is followed by another colon, it's a selector.
  ///
  /// * Otherwise, if the colon is followed by anything other than
  ///   interpolation or a character that's valid as the beginning of an
  ///   identifier, it's a declaration.
  ///
  /// * If the colon is followed by interpolation or a valid identifier, try
  ///   parsing it as a declaration value. If this fails, backtrack and parse
  ///   it as a selector.
  ///
  /// * If the declaration value value valid but is followed by "{", backtrack
  ///   and parse it as a selector anyway. This ensures that ".foo:bar {" is
  ///   always parsed as a selector and never as a property with nested
  ///   properties beneath it.
  Statement _declarationOrStyleRule() {
    var start = _scanner.state;
    var declarationOrBuffer = _declarationOrBuffer();

    if (declarationOrBuffer is Declaration) return declarationOrBuffer;
    var buffer = declarationOrBuffer as InterpolationBuffer;
    buffer.addInterpolation(_almostAnyValue());

    var children = _styleRuleChildren();
    return new StyleRule(
        buffer.interpolation(_scanner.spanFrom(start)), children,
        span: _scanner.spanFrom(start));
  }

  /// Tries to parse a declaration, and returns the value parsed so far if it
  /// fails.
  ///
  /// This can return either an [InterpolationBuffer], indicating that it
  /// couldn't consume a declaration and that selector parsing should be
  /// attempted; or it can return a [Declaration], indicating that it
  /// successfully consumed a declaration.
  dynamic _declarationOrBuffer() {
    var nameStart = _scanner.state;
    var nameBuffer = new InterpolationBuffer();
    
    // Allow the "*prop: val", ":prop: val", "#prop: val", and ".prop: val"
    // hacks.
    var first = _scanner.peekChar();
    if (first == $colon || first == $asterisk || first == $dot ||
        (first == $hash && _scanner.peekChar(1) != $lbrace)) {
      nameBuffer.writeCharCode(_scanner.readChar());
      nameBuffer.write(_commentText());
    }

    if (!_lookingAtInterpolatedIdentifier()) return nameBuffer;
    nameBuffer.addInterpolation(_interpolatedIdentifier());
    nameBuffer.write(_rawText(_tryComment));

    var midBuffer = new StringBuffer();
    midBuffer.write(_commentText());
    if (!_scanChar($colon)) return nameBuffer;
    midBuffer.writeCharCode($colon);

    // Parse custom properties as declarations no matter what.
    var name = nameBuffer.interpolation(_scanner.spanFrom(nameStart));
    if (name.initialPlain.startsWith('--')) {
      return _customPropertyDeclaration(name);
    }

    if (_scanChar($colon)) {
      return nameBuffer..write(midBuffer)..writeCharCode($colon);
    }

    var postColonWhitespace = _commentText();
    midBuffer.write(postColonWhitespace);
    var couldBeSelector =
        postColonWhitespace.isEmpty && _lookingAtInterpolatedIdentifier();

    Expression value;
    try {
      value = _declarationValue();
      var next = _scanner.peekChar();
      if (next == $lbrace) {
        // Properties that are ambiguous with selectors can't have additional
        // properties nested beneath them, so we force an error.
        if (couldBeSelector) _expectChar($semicolon);
      } else if (next != $semicolon && next != $rbrace) {
        // Force an exception if there isn't a valid end-of-property character
        // but don't consume that character.
        _expectChar($semicolon);
      }
    } on FormatException catch (_) {
      if (!couldBeSelector) rethrow;

      // If the value would be followed by a semicolon, it's definitely supposed
      // to be a property, not a selector.
      var additional = _almostAnyValue();
      if (_scanner.peekChar() == $semicolon) rethrow;

      nameBuffer.write(midBuffer);
      nameBuffer.addInterpolation(additional);
      return nameBuffer;
    }

    _ignoreComments();
    // TODO: nested properties
    return new Declaration(name, value);
  }

  /// Consumes whitespace if available and returns any comments it contained.
  List<Comment> _comments() {
    var nodes = <Comment>[];
    while (true) {
      _whitespace();

      var comment = _tryComment();
      if (comment == null) return nodes;

      nodes.add(comment);
    }
  }

  // ## Expressions

  Expression _expression() {
    var hadComma = false;
    var start = _scanner.state;
    var commaExpressions = <Expression>[];
    while (true) {
      var spaceExpressions = <Expression>[];
      while (true) {
        if (!_isExpressionStart(_scanner.peekChar())) break;
        spaceExpressions.add(_singleExpression());
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

    if (commaExpressions.isEmpty) _scanner.error("Expected expression.");
    if (!hadComma) return commaExpressions.single;
    return new ListExpression(commaExpressions, ListSeparator.comma,
        span: _scanner.spanFrom(start));
  }

  Expression _singleExpression() {
    var first = _scanner.peekChar();
    switch (first) {
      // Note: when adding a new case, make sure it's reflected in
      // [_isExpressionStart].
      case $lparen: return _parentheses();
      case $slash: return _unaryOperator();
      case $dot: return _number();
      case $lbracket: return _bracketList();
      case $dollar: return _variable();

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
        if (_lookingAtInterpolatedIdentifier()) return _identifierLike();

        return _unaryOperator();

      default:
        if (first == null) _scanner.error("Expected expression.");

        if (_isNameStart(first) || first == $backslash) {
          return _identifierLike();
        }
        if (_isDigit(first)) return _number();

        _scanner.error("Expected expression");
        throw "Unreachable";
    }
  }


  Expression _parentheses() {
    var start = _scanner.state;
    _expectChar($lparen);
    _ignoreComments();
    if (!_isExpressionStart(_scanner.peekChar())) {
      _expectChar($rparen);
      return new ListExpression([], ListSeparator.none,
          span: _scanner.spanFrom(start));
    }

    // TODO: support maps
    var result = _expression();
    _expectChar($rparen);
    return result;
  }

  UnaryOperatorExpression _unaryOperator() {
    var start = _scanner.state;
    var operator = _unaryOperatorFor(_scanner.readChar());
    if (operator == null) {
      _scanner.error("Expected unary operator",
          position: _scanner.position - 1);
    }

    _ignoreComments();
    var operand = _singleExpression();
    return new UnaryOperatorExpression(operator, operand,
        span: _scanner.spanFrom(start));
  }

  Expression _number() => throw new UnimplementedError();
  Expression _bracketList() => throw new UnimplementedError();

  VariableExpression _variable() {
    var start = _scanner.state;
    _expectChar($dollar);
    var name = _identifier();
    return new VariableExpression(name, span: _scanner.spanFrom(start));
  }

  StringExpression _string() => throw new UnimplementedError();
  Expression _hexColor() => throw new UnimplementedError();

  Expression _identifierLike() {
    // TODO: url(), functions
    var identifier = _interpolatedIdentifier();
    if (identifier.asPlain == "not") {
      _ignoreComments();
      return new UnaryOperatorExpression(
          UnaryOperator.not, _singleExpression());
    } else {
      return new IdentifierExpression(identifier);
    }
  }

  /// Consumes tokens up to "{", "}", ";", or "!".
  ///
  /// This respects string boundaries and supports interpolation. Once this
  /// interpolation is evaluated, it's expected to be re-parsed.
  InterpolationExpression _almostAnyValue() {
    var start = _scanner.state;
    var buffer = new InterpolationBuffer();

    loop: while (true) {
      var next = _scanner.peekChar();
      switch (next) {
        case $backslash:
          // Write a literal backslash because this text will be re-parsed.
          buffer.writeCharCode(_scanner.readChar());
          buffer.writeCharCode(_scanner.readChar());
          break;

        case $double_quote:
        case $single_quote:
          buffer.addInterpolation(_string().asInterpolation);
          break;

        case $slash:
          switch (_scanner.peekChar(1)) {
            case $slash:
              buffer.write(_rawText(() => _silentComment()));
              break;

            case $asterisk:
              buffer.write(_rawText(() => _loudComment()));
              break;

            default:
              buffer.writeCharCode(_scanner.readChar());
              break;
          }
          break;

        case $hash:
          if (_scanner.peekChar(1) == $lbrace) {
            buffer.add(_singleInterpolation());
          } else {
            buffer.writeCharCode(_scanner.readChar());
          }
          break;

        case $exclamation:
        case $semicolon:
        case $lbrace:
        case $rbrace:
          break loop;

        default:
          if (next == null) break loop;

          // TODO: support url()
          buffer.writeCharCode(_scanner.readChar());
          break;
      }
    }

    return buffer.interpolation(_scanner.spanFrom(start));
  }

  InterpolationExpression _interpolatedIdentifier() {
    var start = _scanner.state;
    var buffer = new InterpolationBuffer();

    while (_scanChar($dash)) {
      buffer.writeCharCode($dash);
    }

    var first = _scanner.peekChar();
    if (first == null) {
      _scanner.error("Expected identifier.");
    } else if (_isNameStart(first)) {
      buffer.writeCharCode(_scanner.readChar());
    } else if (first == $backslash) {
      buffer.writeCharCode(_escape());
    } else if (first == $hash && _scanner.peekChar(1) == $lbrace) {
      buffer.add(_singleInterpolation());
    }

    while (true) {
      var next = _scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $underscore || next == $dash ||
          _isAlphabetic(next) || _isDigit(next) || next >= 0x0080) {
        buffer.writeCharCode(_scanner.readChar());
      } else if (next == $backslash) {
        buffer.writeCharCode(_escape());
      } else if (next == $hash && _scanner.peekChar(1) == $lbrace) {
        buffer.add(_singleInterpolation());
      } else {
        break;
      }
    }

    return buffer.interpolation(_scanner.spanFrom(start));
  }

  Expression _singleInterpolation() {
    _scanner.expect('#{');
    var expression = _expression();
    _expectChar($rbrace);
    return expression;
  }

  // ## Tokens

  String _commentText() => _rawText(_ignoreComments);

  void _ignoreComments() {
    do {
      _whitespace();
    } while (_tryComment() != null);
  }

  Comment _tryComment() {
    if (_scanner.peekChar() != $slash) return null;
    switch (_scanner.peekChar(1)) {
      case $slash: return _silentComment();
      case $asterisk: return _loudComment();
      default: return null;
    }
  }

  Comment _silentComment() {
    var start = _scanner.state;
    _scanner.expect("//");

    do {
      while (!_scanner.isDone && !_isNewline(_scanner.readChar())) {}
      if (_scanner.isDone) break;
      _whitespace();
    } while (_scanner.scan("//"));

    return new Comment(_scanner.substring(start.position),
        silent: true,
        span: _scanner.spanFrom(start));
  }

  Comment _loudComment() {
    var start = _scanner.state;
    _scanner.expect("/*");
    do {
      while (_scanner.readChar() != $asterisk) {}
    } while (_scanner.readChar() != $slash);

    return new Comment(_scanner.substring(start.position),
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

  bool _isExpressionStart(int character) =>
      character == $lparen || character == $slash || character == $dot ||
      character == $lbracket || character == $single_quote ||
      character == $double_quote || character == $hash || character == $plus ||
      character == $minus || character == $backslash || character == $dollar ||
      _isNameStart(character) || _isDigit(character);

  int _asHex(int character) {
    if (character <= $9) return character - $0;
    if (character <= $F) return 10 + character - $A;
    return 10 + character - $A;
  }

  UnaryOperator _unaryOperatorFor(int character) {
    switch (character) {
      case $plus: return UnaryOperator.plus;
      case $minus: return UnaryOperator.minus;
      case $slash: return UnaryOperator.divide;
      default: return null;
    }
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

  // ## Utilities

  /// This is based on [the CSS algorithm][], but it assumes all backslashes
  /// start escapes and it considers interpolation to be valid in an identifier.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  bool _lookingAtInterpolatedIdentifier() {
    var first = _scanner.peekChar();
    if (_isNameStart(first) || first == $backslash) return true;
    if (first == $hash) return _scanner.peekChar(1) == $lbrace;

    if (first != $dash) return false;
    var second = _scanner.peekChar();
    if (_isNameStart(second) || second == $backslash) return true;
    return second == $hash && _scanner.peekChar(2) == $lbrace;
  }

  String _rawText(void consumer()) {
    var start = _scanner.position;
    consumer();
    return _scanner.substring(start);
  }
}
