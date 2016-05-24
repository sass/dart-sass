// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import 'ast/node.dart';
import 'ast/comment.dart';
import 'ast/declaration.dart';
import 'ast/expression.dart';
import 'ast/expression/identifier.dart';
import 'ast/expression/interpolation.dart';
import 'ast/expression/list.dart';
import 'ast/expression/string.dart';
import 'ast/style_rule.dart';
import 'ast/stylesheet.dart';
import 'ast/variable_declaration.dart';
import 'interpolation_buffer.dart';

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
          children.add(_styleRule());
          break;
      }
    } while (_scanChar($semicolon));

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

  StyleRuleNode _styleRule() {
    var start = _scanner.state;
    var selector = _almostAnyValue();
    var children = _styleRuleChildren();
    return new StyleRuleNode(selector, children,
        span: _scanner.spanFrom(start));
  }

  List<AstNode> _styleRuleChildren() {
    _expectChar($lbrace);
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

        case $semicolon:
        case $rbrace:
          break;

        default:
          children.add(_declarationOrStyleRule());
          break;
      }
    } while (_scanChar($semicolon));

    children.addAll(_comments());
    _expectChar($rbrace);
    return children;
  }

  Expression _declarationValue() {
    if (_scanner.peekChar() == $lbrace) {
      return new StringExpression([], span: _scanner.emptySpan);
    }

    // TODO: parse static values specially?
    return _expression();
  }

  AstNode _customPropertyDeclaration(InterpolationExpression name) =>
      throw new UnimplementedError();

  /// Parses a [DeclarationNode] or a [StyleRuleNode].
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
  AstNode _declarationOrStyleRule() {
    var start = _scanner.state;
    var declarationOrBuffer = _declarationOrBuffer();

    if (declarationOrBuffer is DeclarationNode) return declarationOrBuffer;
    var buffer = declarationOrBuffer as InterpolationBuffer;
    buffer.addInterpolation(_almostAnyValue());

    var children = _styleRuleChildren();
    return new StyleRuleNode(
        buffer.interpolation(_scanner.spanFrom(start)), children,
        span: _scanner.spanFrom(start));
  }

  
  /// Tries to parse a declaration, and returns the value parsed so far if it
  /// fails.
  ///
  /// This can return either an [InterpolationBuffer], indicating that it
  /// couldn't consume a declaration and that selector parsing should be
  /// attempted; or it can return a [DeclarationNode], indicating that it
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
    return new DeclarationNode(name, value);
  }

  /// Consumes whitespace if available and returns any comments it contained.
  List<CommentNode> _comments() {
    var nodes = <CommentNode>[];
    while (true) {
      _whitespace();

      var comment = _tryComment();
      if (comment == null) return nodes;

      nodes.add(comment);
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
  StringExpression _string() => throw new UnimplementedError();
  Expression _hexColor() => throw new UnimplementedError();

  Expression _identifierLike() {
    // TODO: url(), functions
    return new IdentifierExpression(_interpolatedIdentifier());
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

  CommentNode _tryComment() {
    if (_scanner.peekChar() != $slash) return null;
    switch (_scanner.peekChar(1)) {
      case $slash: return _silentComment();
      case $asterisk: return _loudComment();
      default: return null;
    }
  }

  CommentNode _silentComment() {
    var start = _scanner.state;
    _scanner.expect("//");

    do {
      while (!_scanner.isDone && !_isNewline(_scanner.readChar())) {}
      if (_scanner.isDone) break;
      _whitespace();
    } while (_scanner.scan("//"));

    return new CommentNode(_scanner.substring(start.position),
        silent: true,
        span: _scanner.spanFrom(start));
  }

  CommentNode _loudComment() {
    var start = _scanner.state;
    _scanner.expect("/*");
    do {
      while (_scanner.readChar() != $asterisk) {}
    } while (_scanner.readChar() != $slash);

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

  // ## Utilities

  /// Based on [the CSS algorithm][], but also considers interpolation to be
  /// valid in an identifier.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  bool _lookingAtInterpolatedIdentifier() {
    var first = _scanner.peekChar();
    if (_isNameStart(first)) return true;
    if (first == $backslash) return !_isNewline(_scanner.peekChar(1));
    if (first == $hash) return _scanner.peekChar(1) == $lbrace;

    if (first != $dash) return false;

    var second = _scanner.peekChar();
    if (_isNameStart(second)) return true;
    if (second == $hash) return _scanner.peekChar(2) == $lbrace;
    return second == $backslash && !_isNewline(_scanner.peekChar(2));
  }

  String _rawText(void consumer()) {
    var start = _scanner.position;
    consumer();
    return _scanner.substring(start);
  }
}
