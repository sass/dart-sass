// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import 'ast/sass.dart';
import 'ast/selector.dart';
import 'exception.dart';
import 'interpolation_buffer.dart';
import 'util/character.dart';
import 'utils.dart';
import 'value.dart';

final _selectorPseudoClasses = new Set.from(
    ["not", "matches", "current", "any", "has", "host", "host-context"]);

final _prefixedSelectorPseudoClasses =
    new Set.from(["nth-child", "nth-last-child"]);

class Parser {
  final SpanScanner _scanner;

  var _inMixin = false;

  var _inContentBlock = false;

  var _inControlDirective = false;

  bool _mixinHasContent;

  Parser(String contents, {url})
      : _scanner = new SpanScanner(contents, sourceUrl: url);

  // Conventions:
  //
  // * All statement functions consume through following whitespace, including
  //   comments. No other functions do so unless explicitly specified.

  // ## Statements

  Stylesheet parse() {
    return _wrapFormatException(() {
      var start = _scanner.state;
      var statements = _statements(_topLevelStatement);
      _scanner.expectDone();
      return new Stylesheet(statements, _scanner.spanFrom(start));
    });
  }

  SelectorList parseSelector() {
    return _wrapFormatException(() {
      var selector = _selectorList();
      _scanner.expectDone();
      return selector;
    });
  }

  SimpleSelector parseSimpleSelector() {
    return _wrapFormatException(() {
      var simple = _simpleSelector();
      _scanner.expectDone();
      return simple;
    });
  }

  AtRootQuery parseAtRootQuery() {
    return _wrapFormatException(() {
      _scanner.expectChar($lparen);
      _ignoreComments();
      _expectCaseInsensitive("with");
      var include = !_scanCaseInsensitive("out");
      _ignoreComments();
      _scanner.expectChar($colon);
      _ignoreComments();

      var atRules = new Set<String>();
      do {
        atRules.add(_identifier().toLowerCase());
        _ignoreComments();
      } while (_lookingAtIdentifier());

      return new AtRootQuery(include, atRules);
    });
  }

  Statement _topLevelStatement() {
    if (_scanner.peekChar() == $at) return _atRule(_topLevelStatement);
    return _styleRule();
  }

  VariableDeclaration _variableDeclaration() {
    if (!_scanner.scanChar($dollar)) return null;

    var start = _scanner.state;
    var name = _identifier();
    _ignoreComments();
    _scanner.expectChar($colon);
    _ignoreComments();

    var expression = _expression();

    var guarded = false;
    var global = false;
    while (_scanner.scanChar($exclamation)) {
      var flagStart = _scanner.position - 1;
      var flag = _identifier();
      if (flag == 'default') {
        guarded = true;
      } else if (flag == 'global') {
        global = true;
      } else {
        _scanner.error("Invalid flag name.",
            position: flagStart, length: _scanner.position - flagStart);
      }

      _ignoreComments();
    }

    return new VariableDeclaration(name, expression, _scanner.spanFrom(start),
        guarded: guarded, global: global);
  }

  StyleRule _styleRule() {
    var start = _scanner.state;
    var selector = _almostAnyValue();
    var children = _children(_ruleChild);
    return new StyleRule(selector, children, _scanner.spanFrom(start));
  }

  Statement _ruleChild() {
    if (_scanner.peekChar() == $at) return _atRule(_ruleChild);
    return _declarationOrStyleRule();
  }

  Expression _declarationExpression() {
    if (_scanner.peekChar() == $lbrace) {
      return new StringExpression(new Interpolation([], _scanner.emptySpan));
    }

    return _expression();
  }

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
    var selectorSpan = _scanner.spanFrom(start);

    var children = _children(_ruleChild);
    return new StyleRule(
        buffer.interpolation(selectorSpan), children, _scanner.spanFrom(start));
  }

  /// Tries to parse a declaration, and returns the value parsed so far if it
  /// fails.
  ///
  /// This can return either an [InterpolationBuffer], indicating that it
  /// couldn't consume a declaration and that selector parsing should be
  /// attempted; or it can return a [Declaration], indicating that it
  /// successfully consumed a declaration.
  dynamic _declarationOrBuffer() {
    var start = _scanner.state;
    var nameBuffer = new InterpolationBuffer();

    // Allow the "*prop: val", ":prop: val", "#prop: val", and ".prop: val"
    // hacks.
    var first = _scanner.peekChar();
    if (first == $colon ||
        first == $asterisk ||
        first == $dot ||
        (first == $hash && _scanner.peekChar(1) != $lbrace)) {
      nameBuffer.writeCharCode(_scanner.readChar());
      nameBuffer.write(_commentText());
    }

    if (!_lookingAtInterpolatedIdentifier()) return nameBuffer;
    nameBuffer.addInterpolation(_interpolatedIdentifier());
    nameBuffer.write(_rawText(_tryComment));

    var midBuffer = new StringBuffer();
    midBuffer.write(_commentText());
    if (!_scanner.scanChar($colon)) return nameBuffer;
    midBuffer.writeCharCode($colon);

    // Parse custom properties as declarations no matter what.
    var name = nameBuffer.interpolation(_scanner.spanFrom(start));
    if (name.initialPlain.startsWith('--')) {
      var value = _declarationValue();
      var next = _scanner.peekChar();
      if (next != $semicolon && next != $rbrace) {
        _scanner.expectChar($semicolon);
      }
      return new Declaration(name, _scanner.spanFrom(start), value: value);
    }

    if (_scanner.scanChar($colon)) {
      return nameBuffer
        ..write(midBuffer)
        ..writeCharCode($colon);
    }

    var postColonWhitespace = _commentText();
    if (_scanner.peekChar() == $lbrace) {
      return new Declaration(name, _scanner.spanFrom(start),
          children: _children(_declarationChild));
    }

    midBuffer.write(postColonWhitespace);
    var couldBeSelector =
        postColonWhitespace.isEmpty && _lookingAtInterpolatedIdentifier();

    var beforeDeclaration = _scanner.state;
    Expression value;
    try {
      value = _declarationExpression();
      var next = _scanner.peekChar();
      if (next == $lbrace) {
        // Properties that are ambiguous with selectors can't have additional
        // properties nested beneath them, so we force an error.
        if (couldBeSelector) _scanner.expectChar($semicolon);
      } else if (next != $semicolon && next != $lbrace && next != $rbrace) {
        // Force an exception if there isn't a valid end-of-property character
        // but don't consume that character.
        _scanner.expectChar($semicolon);
      }
    } on FormatException catch (_) {
      if (!couldBeSelector) rethrow;

      // If the value would be followed by a semicolon, it's definitely supposed
      // to be a property, not a selector.
      _scanner.state = beforeDeclaration;
      var additional = _almostAnyValue();
      if (_scanner.peekChar() == $semicolon) rethrow;

      nameBuffer.write(midBuffer);
      nameBuffer.addInterpolation(additional);
      return nameBuffer;
    }

    return new Declaration(name, _scanner.spanFrom(start),
        value: value,
        children: _scanner.peekChar() == $lbrace
            ? _children(_declarationChild)
            : null);
  }

  Declaration _declaration() {
    var start = _scanner.state;
    var name = _interpolatedIdentifier();
    _ignoreComments();
    _scanner.expectChar($colon);
    _ignoreComments();

    if (_scanner.peekChar() == $lbrace) {
      return new Declaration(name, _scanner.spanFrom(start),
          children: _children(_declarationChild));
    }

    var value = _declarationExpression();
    return new Declaration(name, _scanner.spanFrom(start),
        value: value,
        children: _scanner.peekChar() == $lbrace
            ? _children(_declarationChild)
            : null);
  }

  Statement _declarationChild() {
    if (_scanner.peekChar() == $at) return _declarationAtRule();
    return _declaration();
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

  // ## At Rules

  Statement _atRule(Statement child()) {
    var start = _scanner.state;
    var name = _atRuleName();

    switch (name) {
      case "at-root":
        return _atRoot(start);
      case "content":
        return _content(start);
      case "extend":
        return _extend(start);
      case "function":
        return _functionDeclaration(start);
      case "if":
        return _if(start, child);
      case "import":
        return _import(start);
      case "include":
        return _include(start);
      case "media":
        return _mediaRule(start);
      case "mixin":
        return _mixinDeclaration(start);
      case "return":
        return _disallowedAtRule(start);
      case "supports":
        return _supportsRule(start);
      default:
        return _unknownAtRule(start, name);
    }
  }

  Statement _declarationAtRule() {
    var start = _scanner.state;
    var name = _atRuleName();

    switch (name) {
      case "content":
        return _content(start);
      case "if":
        return _if(start, _declarationChild);
      case "include":
        return _include(start);
      default:
        return _disallowedAtRule(start);
    }
  }

  Statement _functionAtRule() {
    var start = _scanner.state;
    switch (_atRuleName()) {
      case "if":
        return _if(start, _functionAtRule);
      case "return":
        return _return(start);
      default:
        return _disallowedAtRule(start);
    }
  }

  String _atRuleName() {
    _scanner.expectChar($at);
    var name = _identifier();
    _ignoreComments();
    return name;
  }

  AtRoot _atRoot(LineScannerState start) {
    var next = _scanner.peekChar();
    var query = next == $hash || next == $lparen ? _queryExpression() : null;
    _ignoreComments();
    return new AtRoot(_children(_topLevelStatement), _scanner.spanFrom(start),
        query: query);
  }

  Content _content(LineScannerState start) {
    if (_inMixin) {
      _mixinHasContent = true;
      return new Content(_scanner.spanFrom(start));
    }

    _scanner.error("@content is only allowed within mixin declarations.",
        position: start.position, length: "@content".length);
    return null;
  }

  Extend _extend(LineScannerState start) {
    var value = _almostAnyValue();
    var optional = _scanner.scanChar($exclamation);
    if (optional) _expectCaseInsensitive("optional");
    return new Extend(value, _scanner.spanFrom(start), optional: optional);
  }

  FunctionDeclaration _functionDeclaration(LineScannerState start) {
    var name = _identifier();
    _ignoreComments();
    var arguments = _argumentDeclaration();

    if (_inMixin || _inContentBlock) {
      throw new StringScannerException(
          "Mixins may not contain function declarations.",
          _scanner.spanFrom(start),
          _scanner.string);
    }

    _ignoreComments();
    var children = _children(_functionAtRule);

    // TODO: ensure there aren't duplicate argument names.
    return new FunctionDeclaration(
        name, arguments, children, _scanner.spanFrom(start));
  }

  If _if(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var expression = _expression();
    var children = _children(child);
    _inControlDirective = wasInControlDirective;
    return new If(expression, children, _scanner.spanFrom(start));
  }

  Statement _import(LineScannerState start) {
    if (_inControlDirective) {
      _disallowedAtRule(start);
      return null;
    }

    // TODO: wrap error with a span
    // TODO: parse supports clauses, url(), and query lists
    var urlString = _string(static: true).text.asPlain;
    var url = Uri.parse(urlString);
    if (_isPlainImportUrl(urlString)) {
      return new PlainImport(url, _scanner.spanFrom(start));
    } else {
      return new Import(url, _scanner.spanFrom(start));
    }
  }

  bool _isPlainImportUrl(String url) {
    if (url.length < "//".length) return false;

    var first = url.codeUnitAt(0);
    if (first == $slash) return url.codeUnitAt(1) == $slash;
    if (first != $h) return false;
    return url.startsWith("http://") || url.startsWith("https://");
  }

  Include _include(LineScannerState start) {
    var name = _identifier();
    _ignoreComments();
    var arguments = _scanner.peekChar() == $lparen
        ? _argumentInvocation()
        : new ArgumentInvocation.empty(_scanner.emptySpan);
    _ignoreComments();

    List<Statement> children;
    if (_scanner.peekChar() == $lbrace) {
      _inContentBlock = true;
      children = _children(_ruleChild);
      _inContentBlock = false;
    }

    return new Include(name, arguments, _scanner.spanFrom(start),
        children: children);
  }

  MediaRule _mediaRule(LineScannerState start) => new MediaRule(
      _mediaQueryList(), _children(_ruleChild), _scanner.spanFrom(start));

  MixinDeclaration _mixinDeclaration(LineScannerState start) {
    var name = _identifier();
    _ignoreComments();
    var arguments = _scanner.peekChar() == $lparen
        ? _argumentDeclaration()
        : new ArgumentDeclaration.empty(span: _scanner.emptySpan);

    if (_inMixin || _inContentBlock) {
      throw new StringScannerException(
          "Mixins may not contain mixin declarations.",
          _scanner.spanFrom(start),
          _scanner.string);
    }

    _ignoreComments();
    _inMixin = true;
    _mixinHasContent = false;
    var children = _children(_ruleChild);
    _inMixin = false;

    return new MixinDeclaration(
        name, arguments, children, _scanner.spanFrom(start),
        hasContent: _mixinHasContent);
  }

  Return _return(LineScannerState start) =>
      new Return(_expression(), _scanner.spanFrom(start));

  SupportsRule _supportsRule(LineScannerState start) {
    var condition = _supportsCondition();
    _ignoreComments();
    return new SupportsRule(
        condition, _children(_ruleChild), _scanner.spanFrom(start));
  }

  AtRule _unknownAtRule(LineScannerState start, String name) {
    Interpolation value;
    var next = _scanner.peekChar();
    if (next != $exclamation &&
        next != $semicolon &&
        next != $lbrace &&
        next != $rbrace &&
        next != null) {
      value = _almostAnyValue();
    }

    return new AtRule(name, _scanner.spanFrom(start),
        value: value,
        children:
            _scanner.peekChar() == $lbrace ? _children(_ruleChild) : null);
  }

  // This returns [Statement] so that it can be returned within case statements.
  Statement _disallowedAtRule(LineScannerState start) {
    _almostAnyValue();
    _scanner.error("This at-rule is not allowed here.",
        position: start.position,
        length: _scanner.state.position - start.position);
    return null;
  }

  ArgumentDeclaration _argumentDeclaration() {
    var start = _scanner.state;
    _scanner.expectChar($lparen);
    _ignoreComments();
    var arguments = <Argument>[];
    String restArgument;
    while (_scanner.peekChar() == $dollar) {
      var variableStart = _scanner.state;
      var name = _variableName();
      _ignoreComments();

      Expression defaultValue;
      if (_scanner.scanChar($colon)) {
        _ignoreComments();
        defaultValue = _spaceListOrValue();
      } else if (_scanner.scanChar($dot)) {
        _scanner.expectChar($dot);
        _scanner.expectChar($dot);
        restArgument = name;
        break;
      }

      arguments.add(new Argument(name,
          span: _scanner.spanFrom(variableStart), defaultValue: defaultValue));
      if (!_scanner.scanChar($comma)) break;
      _ignoreComments();
    }
    _scanner.expectChar($rparen);
    return new ArgumentDeclaration(arguments,
        restArgument: restArgument, span: _scanner.spanFrom(start));
  }

  // ## Expressions

  ArgumentInvocation _argumentInvocation() {
    var start = _scanner.state;
    _scanner.expectChar($lparen);
    _ignoreComments();

    var positional = <Expression>[];
    var named = <String, Expression>{};
    Expression rest;
    Expression keywordRest;
    while (_lookingAtExpression()) {
      var expression = _spaceListOrValue();
      _ignoreComments();

      if (expression is VariableExpression && _scanner.scanChar($colon)) {
        _ignoreComments();
        named[expression.name] = _spaceListOrValue();
      } else if (_scanner.scanChar($dot)) {
        _scanner.expectChar($dot);
        _scanner.expectChar($dot);
        if (rest == null) {
          rest = expression;
        } else {
          keywordRest = expression;
          _ignoreComments();
          break;
        }
      } else if (named.isNotEmpty) {
        _scanner.expect("...");
      } else {
        positional.add(expression);
      }

      _ignoreComments();
      if (!_scanner.scanChar($comma)) break;
      _ignoreComments();
    }
    _scanner.expectChar($rparen);

    return new ArgumentInvocation(positional, named, _scanner.spanFrom(start),
        rest: rest, keywordRest: keywordRest);
  }

  Expression _expression() {
    var first = _singleExpression();
    _ignoreComments();
    if (_lookingAtExpression()) {
      var spaceExpressions = [first];
      do {
        spaceExpressions.add(_singleExpression());
        _ignoreComments();
      } while (_lookingAtExpression());
      first = new ListExpression(spaceExpressions, ListSeparator.space);
    }

    if (!_scanner.scanChar($comma)) return first;

    var commaExpressions = [first];
    do {
      _ignoreComments();
      if (!_lookingAtExpression()) break;
      commaExpressions.add(_spaceListOrValue());
    } while (_scanner.scanChar($comma));

    return new ListExpression(commaExpressions, ListSeparator.comma);
  }

  ListExpression _bracketedList() {
    var start = _scanner.state;
    _scanner.expectChar($lbracket);
    _ignoreComments();

    var expressions = <Expression>[];
    while (!_scanner.scanChar($lbracket)) {
      expressions.add(_spaceListOrValue());
      _ignoreComments();
      if (!_scanner.scanChar($comma)) break;
    }

    return new ListExpression(expressions, ListSeparator.comma,
        bracketed: true, span: _scanner.spanFrom(start));
  }

  Expression _spaceListOrValue() {
    var first = _singleExpression();
    _ignoreComments();
    if (!_lookingAtExpression()) return first;

    var spaceExpressions = [first];
    do {
      spaceExpressions.add(_singleExpression());
      _ignoreComments();
    } while (_lookingAtExpression());

    return new ListExpression(spaceExpressions, ListSeparator.space);
  }

  Expression _singleExpression() {
    var first = _scanner.peekChar();
    switch (first) {
      // Note: when adding a new case, make sure it's reflected in
      // [lookingAtExpression].
      case $lparen:
        return _parentheses();
      case $slash:
        return _unaryOperator();
      case $dot:
        return _number();
      case $lbracket:
        return _bracketedList();
      case $dollar:
        return _variable();

      case $single_quote:
      case $double_quote:
        return _string();

      case $hash:
        if (_scanner.peekChar(1) == $lbrace) return _identifierLike();
        return _hexColorOrID();

      case $plus:
        var next = _scanner.peekChar(1);
        if (isDigit(next) || next == $dot) return _number();

        return _unaryOperator();

      case $minus:
        var next = _scanner.peekChar(1);
        if (isDigit(next) || next == $dot) return _number();
        if (_lookingAtInterpolatedIdentifier()) return _identifierLike();

        return _unaryOperator();

      default:
        if (first == null) _scanner.error("Expected expression.");

        if (isNameStart(first) || first == $backslash) {
          return _identifierLike();
        }
        if (isDigit(first)) return _number();

        _scanner.error("Expected expression");
        throw "Unreachable";
    }
  }

  Expression _parentheses() {
    var start = _scanner.state;
    _scanner.expectChar($lparen);
    _ignoreComments();
    if (!_lookingAtExpression()) {
      _scanner.expectChar($rparen);
      return new ListExpression([], ListSeparator.undecided,
          span: _scanner.spanFrom(start));
    }

    var first = _spaceListOrValue();
    if (_scanner.scanChar($colon)) {
      _ignoreComments();
      return _map(first, start);
    }

    if (_scanner.peekChar() != $comma) {
      _scanner.expectChar($rparen);
      return first;
    }

    var expressions = [first];
    while (true) {
      if (_lookingAtExpression()) break;
      expressions.add(_spaceListOrValue());
      if (!_scanner.scanChar($comma)) break;
      _ignoreComments();
    }

    _scanner.expectChar($lparen);
    return new ListExpression(expressions, ListSeparator.comma,
        span: _scanner.spanFrom(start));
  }

  MapExpression _map(Expression first, LineScannerState start) {
    var pairs = [new Pair(first, _spaceListOrValue())];

    while (_scanner.scanChar($comma)) {
      _ignoreComments();
      if (!_lookingAtExpression()) break;

      var key = _spaceListOrValue();
      _scanner.expectChar($colon);
      _ignoreComments();
      var value = _spaceListOrValue();
      pairs.add(new Pair(key, value));
    }

    _scanner.expectChar($rparen);
    return new MapExpression(pairs, _scanner.spanFrom(start));
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
    return new UnaryOperatorExpression(
        operator, operand, _scanner.spanFrom(start));
  }

  NumberExpression _number() {
    var start = _scanner.state;
    var first = _scanner.peekChar();
    var sign = first == $dash ? -1 : 1;
    if (first == $plus || first == $minus) _scanner.readChar();

    num number = 0;
    var second = _scanner.peekChar();
    if (!isDigit(second) && second != $dot) _scanner.error("Expected number.");

    while (isDigit(_scanner.peekChar())) {
      number *= 10;
      number += _scanner.readChar() - $0;
    }

    if (_scanner.peekChar() == $dot) {
      _scanner.readChar();
      if (!isDigit(_scanner.peekChar())) _scanner.error("Expected digit.");

      var decimal = 0.1;
      while (isDigit(_scanner.peekChar())) {
        number += (_scanner.readChar() - $0) * decimal;
        decimal /= 10;
      }
    }

    var next = _scanner.peekChar();
    if (next == $e || next == $E) {
      _scanner.readChar();
      next = _scanner.peekChar();
      var exponentSign = next == $dash ? -1 : 1;
      if (next == $plus || next == $minus) _scanner.readChar();
      if (!isDigit(_scanner.peekChar())) _scanner.error("Expected digit.");

      var exponent = 0.0;
      while (isDigit(_scanner.peekChar())) {
        exponent *= 10;
        exponent += _scanner.readChar() - $0;
      }

      number = number * math.pow(10, exponentSign * exponent);
    }

    return new NumberExpression(sign * number, _scanner.spanFrom(start));
  }

  VariableExpression _variable() {
    var start = _scanner.state;
    return new VariableExpression(_variableName(), _scanner.spanFrom(start));
  }

  StringExpression _string({bool static: false}) {
    var start = _scanner.state;
    var quote = _scanner.readChar();

    if (quote != $single_quote && quote != $double_quote) {
      _scanner.error("Expected string.", position: start.position);
    }

    var buffer = new InterpolationBuffer();
    while (true) {
      var next = _scanner.peekChar();
      if (next == quote) {
        _scanner.readChar();
        break;
      } else if (next == null || isNewline(next)) {
        _scanner.error("Expected ${new String.fromCharCode(quote)}.");
      } else if (next == $backslash) {
        if (isNewline(_scanner.peekChar(1))) {
          _scanner.readChar();
          _scanner.readChar();
        } else {
          buffer.writeCharCode(_escape());
        }
      } else if (next == $hash && !static) {
        if (_scanner.peekChar(1) == $lbrace) {
          buffer.add(_singleInterpolation());
        } else {
          buffer.writeCharCode(_scanner.readChar());
        }
      } else {
        buffer.writeCharCode(_scanner.readChar());
      }
    }

    return new StringExpression(buffer.interpolation(_scanner.spanFrom(start)));
  }

  Expression _hexColorOrID() {
    var start = _scanner.state;
    _scanner.expectChar($hash);

    var first = _scanner.peekChar();
    if (first != null && isDigit(first)) {
      return new ColorExpression(_hexColorContents(), _scanner.spanFrom(start));
    }

    var afterHash = _scanner.state;
    var identifier = _interpolatedIdentifier();
    if (_isHexColor(identifier)) {
      _scanner.state = afterHash;
      return new ColorExpression(_hexColorContents(), _scanner.spanFrom(start));
    }

    var buffer = new InterpolationBuffer();
    buffer.writeCharCode($hash);
    buffer.addInterpolation(identifier);
    return new IdentifierExpression(
        buffer.interpolation(_scanner.spanFrom(start)));
  }

  SassColor _hexColorContents() {
    var red = _hexDigit();
    var green = _hexDigit();
    var blue = _hexDigit();

    var next = _scanner.peekChar();
    if (next != null && isHex(next)) {
      red = (red << 4) + green;
      green = (blue << 4) + _hexDigit();
      blue = (_hexDigit() << 4) + _hexDigit();
    } else {
      red = (red << 4) + red;
      green = (green << 4) + green;
      blue = (blue << 4) + blue;
    }

    return new SassColor.rgb(red, green, blue);
  }

  bool _isHexColor(Interpolation interpolation) {
    var plain = interpolation.asPlain;
    if (plain == null) return false;
    if (plain.length != 3 && plain.length != 6) return false;
    return plain.codeUnits.every(isHex);
  }

  Expression _identifierLike() {
    // TODO: url()
    var identifier = _interpolatedIdentifier();
    switch (identifier.asPlain) {
      case "not":
        _ignoreComments();
        return new UnaryOperatorExpression(
            UnaryOperator.not, _singleExpression(), identifier.span);

      case "true":
        return new BooleanExpression(true, identifier.span);
      case "false":
        return new BooleanExpression(false, identifier.span);
    }

    return _scanner.peekChar() == $lparen
        ? new FunctionExpression(identifier, _argumentInvocation())
        : new IdentifierExpression(identifier);
  }

  /// Consumes tokens up to "{", "}", ";", or "!".
  ///
  /// This respects string boundaries and supports interpolation. Once this
  /// interpolation is evaluated, it's expected to be re-parsed.
  Interpolation _almostAnyValue() {
    var start = _scanner.state;
    var buffer = new InterpolationBuffer();

    loop:
    while (true) {
      var next = _scanner.peekChar();
      switch (next) {
        case $backslash:
          // Write a literal backslash because this text will be re-parsed.
          buffer.writeCharCode(_scanner.readChar());
          buffer.writeCharCode(_scanner.readChar());
          break;

        case $double_quote:
        case $single_quote:
          buffer.addInterpolation(_string().asInterpolation());
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

  IdentifierExpression _declarationValue({bool static: false}) {
    var start = _scanner.state;
    var buffer = new InterpolationBuffer();

    var brackets = <int>[];
    var wroteNewline = false;
    loop:
    while (true) {
      var next = _scanner.peekChar();
      switch (next) {
        case $backslash:
          buffer.writeCharCode(_escape());
          wroteNewline = false;
          break;

        case $double_quote:
        case $single_quote:
          buffer.addInterpolation(_string(static: static)
              .asInterpolation(static: static, quote: next));
          wroteNewline = false;
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
          wroteNewline = false;
          break;

        case $hash:
          if (!static && _scanner.peekChar(1) == $lbrace) {
            buffer.add(_singleInterpolation());
          } else {
            buffer.writeCharCode(_scanner.readChar());
          }
          wroteNewline = false;
          break;

        case $space:
        case $tab:
          if (wroteNewline || !isWhitespace(_scanner.peekChar(1))) {
            buffer.writeCharCode($space);
          }
          _scanner.readChar();
          break;

        case $lf:
        case $cr:
        case $ff:
          if (!isNewline(_scanner.peekChar(-1))) buffer.writeln();
          _scanner.readChar();
          wroteNewline = true;
          break;

        case $lparen:
        case $lbrace:
        case $lbracket:
          buffer.writeCharCode(next);
          brackets.add(opposite(_scanner.readChar()));
          wroteNewline = false;
          break;

        case $rparen:
        case $rbrace:
        case $rbracket:
          if (brackets.isEmpty) break loop;
          buffer.writeCharCode(next);
          _scanner.expectChar(brackets.removeLast());
          wroteNewline = false;
          break;

        case $exclamation:
        case $semicolon:
          break loop;

        default:
          if (next == null) break loop;

          // TODO: support url()
          buffer.writeCharCode(_scanner.readChar());
          wroteNewline = false;
          break;
      }
    }

    if (brackets.isNotEmpty) _scanner.expectChar(brackets.last);
    return new IdentifierExpression(
        buffer.interpolation(_scanner.spanFrom(start)));
  }

  Interpolation _interpolatedIdentifier() {
    var start = _scanner.state;
    var buffer = new InterpolationBuffer();

    while (_scanner.scanChar($dash)) {
      buffer.writeCharCode($dash);
    }

    var first = _scanner.peekChar();
    if (first == null) {
      _scanner.error("Expected identifier.");
    } else if (isNameStart(first)) {
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
      } else if (next == $underscore ||
          next == $dash ||
          isAlphanumeric(next) ||
          next >= 0x0080) {
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
    _ignoreComments();
    var expression = _expression();
    _scanner.expectChar($rbrace);
    return expression;
  }

  /// A query expression of the form `(foo: bar)`.
  Interpolation _queryExpression() {
    if (_scanner.peekChar() == $hash) {
      var interpolation = _singleInterpolation();
      return new Interpolation([interpolation], interpolation.span);
    }

    var start = _scanner.state;
    var buffer = new InterpolationBuffer();
    _scanner.expectChar($lparen);
    buffer.writeCharCode($lparen);
    _ignoreComments();

    buffer.add(_expression());
    if (_scanner.scanChar($colon)) {
      _ignoreComments();
      buffer.writeCharCode($colon);
      buffer.writeCharCode($space);
      buffer.add(_expression());
    }

    _scanner.expectChar($rparen);
    _ignoreComments();
    buffer.writeCharCode($rparen);

    return buffer.interpolation(_scanner.spanFrom(start));
  }

  // ## Selectors

  SelectorList _selectorList() {
    var components = <ComplexSelector>[];
    var lineBreaks = <int>[];

    _ignoreComments();
    var previousLine = _scanner.line;
    do {
      _ignoreComments();
      var next = _scanner.peekChar();
      if (next == $comma) continue;
      if (next == $lbrace) break;

      if (_scanner.line != previousLine) {
        lineBreaks.add(components.length);
        previousLine = _scanner.line;
      }
      components.add(_complexSelector());
    } while (_scanner.scanChar($comma));

    return new SelectorList(components, lineBreaks: lineBreaks);
  }

  ComplexSelector _complexSelector() {
    var components = <ComplexSelectorComponent>[];
    var lineBreaks = <int>[];

    var previousLine = _scanner.line;
    loop:
    while (true) {
      _ignoreComments();

      ComplexSelectorComponent component;
      var next = _scanner.peekChar();
      switch (next) {
        case $plus:
          component = Combinator.nextSibling;
          break;

        case $gt:
          component = Combinator.child;
          break;

        case $tilde:
          component = Combinator.followingSibling;
          break;

        case $lbracket:
        case $dot:
        case $hash:
        case $percent:
        case $colon:
        case $ampersand:
        case $asterisk:
        case $pipe:
          component = _compoundSelector();
          break;

        default:
          if (next == null || !_lookingAtInterpolatedIdentifier()) break loop;
          component = _compoundSelector();
          break;
      }

      if (_scanner.line != previousLine) {
        lineBreaks.add(components.length);
        previousLine = _scanner.line;
      }
      components.add(component);
    }

    return new ComplexSelector(components, lineBreaks: lineBreaks);
  }

  CompoundSelector _compoundSelector() {
    var components = <SimpleSelector>[_simpleSelector()];

    while (isSimpleSelectorStart(_scanner.peekChar())) {
      components.add(_simpleSelector(allowParent: false));
    }

    // TODO: support "*E".
    return new CompoundSelector(components);
  }

  SimpleSelector _simpleSelector({bool allowParent: true}) {
    switch (_scanner.peekChar()) {
      case $lbracket:
        return _attributeSelector();
      case $dot:
        return _classSelector();
      case $hash:
        return _idSelector();
      case $percent:
        return _placeholderSelector();
      case $colon:
        return _pseudoSelector();
      case $ampersand:
        if (!allowParent) return _typeOrUniversalSelector();
        return _parentSelector();

      default:
        return _typeOrUniversalSelector();
    }
  }

  AttributeSelector _attributeSelector() {
    _scanner.expectChar($lbracket);
    _ignoreComments();

    var name = _attributeName();
    _ignoreComments();
    if (_scanner.scanChar($rbracket)) {
      _scanner.readChar();
      return new AttributeSelector(name);
    }

    var operator = _attributeOperator();
    _ignoreComments();

    var next = _scanner.peekChar();
    var value = next == $single_quote || next == $double_quote
        ? _string(static: true).text.asPlain
        : _identifier();
    _ignoreComments();

    _scanner.expectChar($rbracket);
    return new AttributeSelector.withOperator(name, operator, value);
  }

  NamespacedIdentifier _attributeName() {
    if (_scanner.scanChar($asterisk)) {
      _scanner.expectChar($pipe);
      return new NamespacedIdentifier(_identifier(), namespace: "*");
    }

    var nameOrNamespace = _identifier();
    if (_scanner.peekChar() != $pipe || _scanner.peekChar(1) == $equal) {
      return new NamespacedIdentifier(nameOrNamespace);
    }

    _scanner.readChar();
    return new NamespacedIdentifier(_identifier(), namespace: nameOrNamespace);
  }

  AttributeOperator _attributeOperator() {
    var start = _scanner.state;
    switch (_scanner.readChar()) {
      case $equal:
        return AttributeOperator.equal;

      case $tilde:
        _scanner.expectChar($equal);
        return AttributeOperator.include;

      case $pipe:
        _scanner.expectChar($equal);
        return AttributeOperator.dash;

      case $caret:
        _scanner.expectChar($equal);
        return AttributeOperator.prefix;

      case $dollar:
        _scanner.expectChar($equal);
        return AttributeOperator.suffix;

      case $asterisk:
        _scanner.expectChar($equal);
        return AttributeOperator.substring;

      default:
        _scanner.error('Expected "]".', position: start.position);
        throw "Unreachable";
    }
  }

  ClassSelector _classSelector() {
    _scanner.expectChar($dot);
    var name = _identifier();
    return new ClassSelector(name);
  }

  IDSelector _idSelector() {
    _scanner.expectChar($hash);
    var name = _identifier();
    return new IDSelector(name);
  }

  PlaceholderSelector _placeholderSelector() {
    _scanner.expectChar($percent);
    var name = _identifier();
    return new PlaceholderSelector(name);
  }

  ParentSelector _parentSelector() {
    _scanner.expectChar($ampersand);
    var next = _scanner.peekChar();
    var suffix = isName(next) || next == $backslash ? _identifier() : null;
    return new ParentSelector(suffix: suffix);
  }

  PseudoSelector _pseudoSelector() {
    _scanner.expectChar($colon);
    var type =
        _scanner.scanChar($colon) ? PseudoType.element : PseudoType.klass;
    var name = _identifier();

    if (!_scanner.scanChar($lparen)) {
      return new PseudoSelector(name, type);
    }
    _ignoreComments();

    var unvendored = unvendor(name);
    String argument;
    SelectorList selector;
    if (type == PseudoType.element) {
      argument = _pseudoArgument();
    } else if (_selectorPseudoClasses.contains(unvendored)) {
      selector = _selectorList();
    } else if (_prefixedSelectorPseudoClasses.contains(unvendored)) {
      argument = _rawText(_aNPlusB);
      if (_scanWhitespace()) {
        _expectCaseInsensitive("of");
        argument += " of";
        _ignoreComments();

        selector = _selectorList();
      }
    } else {
      argument = _pseudoArgument();
    }
    _scanner.expectChar($rparen);

    return new PseudoSelector(name, type,
        argument: argument, selector: selector);
  }

  String _pseudoArgument() => _declarationValue(static: true).text.asPlain;

  void _aNPlusB() {
    switch (_scanner.peekChar()) {
      case $e:
      case $E:
        _expectCaseInsensitive("even");
        return;

      case $o:
      case $O:
        _expectCaseInsensitive("odd");
        return;

      case $plus:
      case $minus:
        _scanner.readChar();
        break;
    }

    var first = _scanner.peekChar();
    if (first != null && isDigit(first)) {
      while (isDigit(_scanner.peekChar())) {
        _scanner.readChar();
      }
      _ignoreComments();
      if (!_scanCharCaseInsensitive($n)) return;
    } else {
      _expectCharCaseInsensitive($n);
    }
    _ignoreComments();

    var next = _scanner.peekChar();
    if (next != $plus && next != $minus) return;
    _scanner.readChar();
    _ignoreComments();

    var last = _scanner.peekChar();
    if (last == null || !isDigit(last)) _scanner.error("Expected a number.");
    while (isDigit(_scanner.peekChar())) {
      _scanner.readChar();
    }
  }

  SimpleSelector _typeOrUniversalSelector() {
    var first = _scanner.peekChar();
    if (first == $asterisk) {
      _scanner.readChar();
      if (!_scanner.scanChar($pipe)) return new UniversalSelector();
      if (_scanner.scanChar($asterisk)) {
        return new UniversalSelector(namespace: "*");
      } else {
        return new TypeSelector(
            new NamespacedIdentifier(_identifier(), namespace: "*"));
      }
    } else if (first == $pipe) {
      _scanner.readChar();
      if (_scanner.scanChar($asterisk)) {
        return new UniversalSelector(namespace: "");
      } else {
        return new TypeSelector(
            new NamespacedIdentifier(_identifier(), namespace: ""));
      }
    }

    var nameOrNamespace = _identifier();
    if (!_scanner.scanChar($pipe)) {
      return new TypeSelector(new NamespacedIdentifier(nameOrNamespace));
    }

    return new TypeSelector(
        new NamespacedIdentifier(_identifier(), namespace: nameOrNamespace));
  }

  // ## Media Queries

  List<MediaQuery> _mediaQueryList() {
    var queries = <MediaQuery>[];
    do {
      _ignoreComments();
      queries.add(_mediaQuery());
    } while (_scanner.scanChar($comma));
    return queries;
  }

  MediaQuery _mediaQuery() {
    Interpolation modifier;
    Interpolation type;
    if (_scanner.peekChar() != $lparen) {
      var identifier1 = _interpolatedIdentifier();
      _ignoreComments();

      if (!_lookingAtInterpolatedIdentifier()) {
        // For example, "@media screen {"
        return new MediaQuery(identifier1);
      }

      var identifier2 = _interpolatedIdentifier();
      _ignoreComments();

      if (equalsIgnoreCase(identifier2.asPlain, "and")) {
        // For example, "@media screen and ..."
        type = identifier1;
      } else {
        modifier = identifier1;
        type = identifier2;
        if (_scanCaseInsensitive("and")) {
          // For example, "@media only screen and ..."
          _ignoreComments();
        } else {
          // For example, "@media only screen {"
          return new MediaQuery(type, modifier: modifier);
        }
      }
    }

    // We've consumed either `IDENTIFIER "and"` or
    // `IDENTIFIER IDENTIFIER "and"`.

    var features = <Interpolation>[];
    do {
      _ignoreComments();
      features.add(_queryExpression());
      _ignoreComments();
    } while (_scanCaseInsensitive("and"));

    if (type == null) {
      return new MediaQuery.condition(features);
    } else {
      return new MediaQuery(type, modifier: modifier, features: features);
    }
  }

  // ## Supports Conditions

  SupportsCondition _supportsCondition() {
    var start = _scanner.state;
    var first = _scanner.peekChar();
    if (first != $lparen && first != $hash) {
      var start = _scanner.state;
      _expectCaseInsensitive("not");
      _ignoreComments();
      return new SupportsNegation(
          _supportsConditionInParens(), _scanner.spanFrom(start));
    }

    var condition = _supportsConditionInParens();
    _ignoreComments();
    while (_lookingAtIdentifier()) {
      String operator;
      if (_scanCaseInsensitive("or")) {
        operator = "or";
      } else {
        _expectCaseInsensitive("and");
        operator = "and";
      }

      _ignoreComments();
      var right = _supportsConditionInParens();
      condition = new SupportsOperation(
          condition, right, operator, _scanner.spanFrom(start));
      _ignoreComments();
    }
    return condition;
  }

  SupportsCondition _supportsConditionInParens() {
    var start = _scanner.state;
    if (_scanner.peekChar() == $hash) {
      return new SupportsInterpolation(
          _singleInterpolation(), _scanner.spanFrom(start));
    }

    _scanner.expectChar($lparen);
    _ignoreComments();
    var next = _scanner.peekChar();
    if (next == $lparen || next == $hash) {
      var condition = _supportsCondition();
      _ignoreComments();
      _scanner.expectChar($rparen);
      return condition;
    }

    if (next == $n || next == $N) {
      var negation = _trySupportsNegation();
      if (negation != null) return negation;
    }

    var name = _expression();
    _scanner.expectChar($colon);
    _ignoreComments();
    var value = _expression();
    _scanner.expectChar($rparen);
    return new SupportsDeclaration(name, value, _scanner.spanFrom(start));
  }

  // If this fails, it puts the cursor back at the beginning.
  SupportsNegation _trySupportsNegation() {
    var start = _scanner.state;
    if (!_scanCaseInsensitive("not") || _scanner.isDone) {
      _scanner.state = start;
      return null;
    }

    var next = _scanner.peekChar();
    if (!isWhitespace(next) && next != $lparen) {
      _scanner.state = start;
      return null;
    }

    return new SupportsNegation(
        _supportsConditionInParens(), _scanner.spanFrom(start));
  }

  // ## Tokens

  String _commentText() => _rawText(_ignoreComments);

  bool _scanWhitespace() {
    var start = _scanner.position;
    _ignoreComments();
    return _scanner.position != start;
  }

  void _ignoreComments() {
    do {
      _whitespace();
    } while (_tryComment() != null);
  }

  Comment _tryComment() {
    if (_scanner.peekChar() != $slash) return null;
    switch (_scanner.peekChar(1)) {
      case $slash:
        return _silentComment();
      case $asterisk:
        return _loudComment();
      default:
        return null;
    }
  }

  Comment _silentComment() {
    var start = _scanner.state;
    _scanner.expect("//");

    do {
      while (!_scanner.isDone && !isNewline(_scanner.readChar())) {}
      if (_scanner.isDone) break;
      _whitespace();
    } while (_scanner.scan("//"));

    return new Comment(
        _scanner.substring(start.position), _scanner.spanFrom(start),
        silent: true);
  }

  Comment _loudComment() {
    var start = _scanner.state;
    _scanner.expect("/*");
    do {
      while (_scanner.readChar() != $asterisk) {}
    } while (_scanner.readChar() != $slash);

    return new Comment(
        _scanner.substring(start.position), _scanner.spanFrom(start),
        silent: false);
  }

  void _whitespace() {
    while (!_scanner.isDone && isWhitespace(_scanner.peekChar())) {
      _scanner.readChar();
    }
  }

  String _identifier() {
    var text = new StringBuffer();
    while (_scanner.scanChar($dash)) {
      text.writeCharCode($dash);
    }

    var first = _scanner.peekChar();
    if (first == null) {
      _scanner.error("Expected identifier.");
    } else if (isNameStart(first)) {
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
      } else if (next == $underscore ||
          next == $dash ||
          isAlphanumeric(next) ||
          next >= 0x0080) {
        text.writeCharCode(_scanner.readChar());
      } else if (next == $backslash) {
        text.writeCharCode(_escape());
      } else {
        break;
      }
    }

    return text.toString();
  }

  String _variableName() {
    _scanner.expectChar($dollar);
    return _identifier();
  }

  // ## Characters

  UnaryOperator _unaryOperatorFor(int character) {
    switch (character) {
      case $plus:
        return UnaryOperator.plus;
      case $minus:
        return UnaryOperator.minus;
      case $slash:
        return UnaryOperator.divide;
      default:
        return null;
    }
  }

  int _escape() {
    // See https://drafts.csswg.org/css-syntax-3/#consume-escaped-code-point.

    _scanner.expectChar($backslash);
    var first = _scanner.peekChar();
    if (first == null) {
      return 0xFFFD;
    } else if (isNewline(first)) {
      _scanner.error("Expected escape sequence.");
      return 0;
    } else if (isHex(first)) {
      var value = 0;
      for (var i = 0; i < 6; i++) {
        var next = _scanner.peekChar();
        if (next == null || !isHex(next)) break;
        value = (value << 4) + asHex(_scanner.readChar());
      }
      if (isWhitespace(_scanner.peekChar())) _scanner.readChar();

      if (value == 0 ||
          (value >= 0xD800 && value <= 0xDFFF) ||
          value >= 0x10FFFF) {
        return 0xFFFD;
      } else {
        return value;
      }
    } else {
      return _scanner.readChar();
    }
  }

  int _hexDigit() {
    var char = _scanner.peekChar();
    if (char == null || !isHex(char)) _scanner.error("Expected hex digit.");
    return asHex(_scanner.readChar());
  }

  bool _scanCharCaseInsensitive(int character) {
    assert(character >= $a && character <= $z);
    var actual = _scanner.readChar();
    return actual == character || actual == character + $A - $a;
  }

  void _expectCharCaseInsensitive(int character) {
    assert(character >= $a && character <= $z);
    var actual = _scanner.readChar();
    if (actual == character || actual == character + $A - $a) return;

    _scanner.error('Expected "${new String.fromCharCode(character)}".',
        position: actual == null ? _scanner.position : _scanner.position - 1);
  }

  bool _scanCaseInsensitive(String expected) {
    var start = _scanner.position;
    for (var i = 0; i < expected.length; i++) {
      if (_scanCharCaseInsensitive(expected.codeUnitAt(i))) continue;
      _scanner.position = start;
      return false;
    }
    return true;
  }

  void _expectCaseInsensitive(String expected) {
    var start = _scanner.position;
    for (var i = 0; i < expected.length; i++) {
      if (_scanCharCaseInsensitive(expected.codeUnitAt(i))) continue;
      _scanner.error('Expected "$expected".', position: start, length: i);
    }
  }

  // ## Utilities

  /// This is based on [the CSS algorithm][], but it assumes all backslashes
  /// start escapes and it considers interpolation to be valid in an identifier.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  bool _lookingAtInterpolatedIdentifier() {
    var first = _scanner.peekChar();
    if (isNameStart(first) || first == $backslash) return true;
    if (first == $hash) return _scanner.peekChar(1) == $lbrace;

    if (first != $dash) return false;
    var second = _scanner.peekChar(1);
    if (isNameStart(second) || second == $dash || second == $backslash) {
      return true;
    }
    return second == $hash && _scanner.peekChar(2) == $lbrace;
  }

  bool _lookingAtIdentifier() {
    var first = _scanner.peekChar();
    if (isNameStart(first) || first == $backslash) return true;

    if (first != $dash) return false;
    var second = _scanner.peekChar(1);
    return isNameStart(second) || second == $dash || second == $backslash;
  }

  bool _lookingAtExpression() {
    var character = _scanner.peekChar();
    if (character == null) return false;
    if (character == $dot) return _scanner.peekChar(1) != $dot;

    return character == $lparen ||
        character == $slash ||
        character == $lbracket ||
        character == $single_quote ||
        character == $double_quote ||
        character == $hash ||
        character == $plus ||
        character == $minus ||
        character == $backslash ||
        character == $dollar ||
        isNameStart(character) ||
        isDigit(character);
  }

  List<Statement> _children(Statement child()) {
    _scanner.expectChar($lbrace);
    var children = <Statement>[];
    while (true) {
      children.addAll(_comments());
      switch (_scanner.peekChar()) {
        case $dollar:
          children.add(_variableDeclaration());
          break;

        case $semicolon:
          _scanner.readChar();
          break;

        case $rbrace:
          _scanner.expectChar($rbrace);
          return children;

        default:
          children.add(child());
          break;
      }
    }
  }

  List<Statement> _statements(Statement statement()) {
    var statements = <Statement>[]..addAll(_comments());
    while (!_scanner.isDone) {
      switch (_scanner.peekChar()) {
        case $dollar:
          statements.add(_variableDeclaration());
          break;

        case $semicolon:
          _scanner.readChar();
          break;

        default:
          statements.add(statement());
          break;
      }
      statements.addAll(_comments());
    }
    return statements;
  }

  String _rawText(void consumer()) {
    var start = _scanner.position;
    consumer();
    return _scanner.substring(start);
  }

  /*=T*/ _wrapFormatException/*<T>*/(/*=T*/ callback()) {
    try {
      return callback();
    } on StringScannerException catch (error) {
      throw new SassException(error.message, error.span as FileSpan);
    }
  }
}
