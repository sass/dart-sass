// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../interpolation_buffer.dart';
import '../util/character.dart';
import '../utils.dart';
import '../value.dart';
import 'parser.dart';

/// The base class for both the SCSS and indented syntax parsers.
///
/// Having a base class that's separate from both parsers allows us to make
/// explicit exactly which methods are different between the two. This allows
/// the author to know that if they're modifying the base class, the subclasses
/// generally won't need modification. Conversely, if they're modifying one
/// subclass, the other will likely need a parallel change.
///
/// All methods that are not intended to be accessed by external callers are
/// private, except where they have to be public for subclasses to refer to
/// them.
abstract class StylesheetParser extends Parser {
  var _inMixin = false;

  var _inContentBlock = false;

  var _inControlDirective = false;

  bool _mixinHasContent;

  StylesheetParser(String contents, {url}) : super(contents, url: url);

  // Conventions:
  //
  // * All statement functions consume through following whitespace, including
  //   comments. No other functions do so unless explicitly specified.

  // ## Statements

  Stylesheet parse() {
    return wrapFormatException(() {
      var start = scanner.state;
      var statements = this.statements(_topLevelStatement);
      scanner.expectDone();
      return new Stylesheet(statements, scanner.spanFrom(start));
    });
  }

  ArgumentDeclaration parseArgumentDeclaration() {
    return wrapFormatException(() {
      var declaration = _argumentDeclaration();
      scanner.expectDone();
      return declaration;
    });
  }

  Statement _topLevelStatement() {
    if (scanner.peekChar() == $at) return _atRule(_topLevelStatement);
    return _styleRule();
  }

  VariableDeclaration variableDeclaration() {
    var start = scanner.state;
    var name = variableName();
    whitespace();
    scanner.expectChar($colon);
    whitespace();

    var expression = _expression();

    var guarded = false;
    var global = false;
    while (scanner.scanChar($exclamation)) {
      var flagStart = scanner.position - 1;
      var flag = identifier();
      if (flag == 'default') {
        guarded = true;
      } else if (flag == 'global') {
        global = true;
      } else {
        scanner.error("Invalid flag name.",
            position: flagStart, length: scanner.position - flagStart);
      }

      whitespace();
    }

    return new VariableDeclaration(name, expression, scanner.spanFrom(start),
        guarded: guarded, global: global);
  }

  StyleRule _styleRule() {
    var start = scanner.state;
    var selector = _almostAnyValue();
    var children = this.children(_ruleChild);
    return new StyleRule(selector, children, scanner.spanFrom(start));
  }

  Statement _ruleChild() {
    if (scanner.peekChar() == $at) return _atRule(_ruleChild);
    return _declarationOrStyleRule();
  }

  Expression _declarationExpression() {
    if (lookingAtChildren()) {
      return new StringExpression(new Interpolation([], scanner.emptySpan),
          quotes: true);
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
    var start = scanner.state;
    var declarationOrBuffer = _declarationOrBuffer();

    if (declarationOrBuffer is Declaration) return declarationOrBuffer;
    var buffer = declarationOrBuffer as InterpolationBuffer;
    buffer.addInterpolation(_almostAnyValue());
    var selectorSpan = scanner.spanFrom(start);

    var children = this.children(_ruleChild);
    return new StyleRule(
        buffer.interpolation(selectorSpan), children, scanner.spanFrom(start));
  }

  /// Tries to parse a declaration, and returns the value parsed so far if it
  /// fails.
  ///
  /// This can return either an [InterpolationBuffer], indicating that it
  /// couldn't consume a declaration and that selector parsing should be
  /// attempted; or it can return a [Declaration], indicating that it
  /// successfully consumed a declaration.
  dynamic _declarationOrBuffer() {
    var start = scanner.state;
    var nameBuffer = new InterpolationBuffer();

    // Allow the "*prop: val", ":prop: val", "#prop: val", and ".prop: val"
    // hacks.
    var first = scanner.peekChar();
    if (first == $colon ||
        first == $asterisk ||
        first == $dot ||
        (first == $hash && scanner.peekChar(1) != $lbrace)) {
      nameBuffer.writeCharCode(scanner.readChar());
      nameBuffer.write(rawText(whitespace));
    }

    if (!_lookingAtInterpolatedIdentifier()) return nameBuffer;
    nameBuffer.addInterpolation(_interpolatedIdentifier());
    if (scanner.matches("/*")) nameBuffer.write(rawText(loudComment));

    var midBuffer = new StringBuffer();
    midBuffer.write(rawText(whitespace));
    if (!scanner.scanChar($colon)) return nameBuffer;
    midBuffer.writeCharCode($colon);

    // Parse custom properties as declarations no matter what.
    var name = nameBuffer.interpolation(scanner.spanFrom(start));
    if (name.initialPlain.startsWith('--')) {
      var value = _interpolatedDeclarationValue();
      if (!atEndOfStatement()) {
        if (!indented) scanner.expectChar($semicolon);
        scanner.error("Expected newline.");
      }
      return new Declaration(name, scanner.spanFrom(start), value: value);
    }

    if (scanner.scanChar($colon)) {
      return nameBuffer
        ..write(midBuffer)
        ..writeCharCode($colon);
    }

    var postColonWhitespace = rawText(whitespace);
    if (lookingAtChildren()) {
      return new Declaration(name, scanner.spanFrom(start),
          children: children(_declarationChild));
    }

    midBuffer.write(postColonWhitespace);
    var couldBeSelector =
        postColonWhitespace.isEmpty && _lookingAtInterpolatedIdentifier();

    var beforeDeclaration = scanner.state;
    Expression value;
    try {
      value = _declarationExpression();
      if (lookingAtChildren()) {
        // Properties that are ambiguous with selectors can't have additional
        // properties nested beneath them, so we force an error. This will be
        // caught below and cause the text to be reparsed as a selector.
        if (couldBeSelector) scanner.expectChar($semicolon);
      } else if (!atEndOfStatement()) {
        // Force an exception if there isn't a valid end-of-property character
        // but don't consume that character. This will also cause the text to be
        // reparsed.
        scanner.expectChar($semicolon);
      }
    } on FormatException catch (_) {
      if (!couldBeSelector) rethrow;

      // If the value would be followed by a semicolon, it's definitely supposed
      // to be a property, not a selector.
      scanner.state = beforeDeclaration;
      var additional = _almostAnyValue();
      if (!indented && scanner.peekChar() == $semicolon) rethrow;

      nameBuffer.write(midBuffer);
      nameBuffer.addInterpolation(additional);
      return nameBuffer;
    }

    return new Declaration(name, scanner.spanFrom(start),
        value: value,
        children: lookingAtChildren() ? children(_declarationChild) : null);
  }

  Declaration _declaration() {
    var start = scanner.state;
    var name = _interpolatedIdentifier();
    whitespace();
    scanner.expectChar($colon);
    whitespace();

    if (lookingAtChildren()) {
      return new Declaration(name, scanner.spanFrom(start),
          children: children(_declarationChild));
    }

    var value = _declarationExpression();
    return new Declaration(name, scanner.spanFrom(start),
        value: value,
        children: lookingAtChildren() ? children(_declarationChild) : null);
  }

  Statement _declarationChild() {
    if (scanner.peekChar() == $at) return _declarationAtRule();
    return _declaration();
  }

  // ## At Rules

  Statement _atRule(Statement child()) {
    var start = scanner.state;
    var name = _atRuleName();

    switch (name) {
      case "at-root":
        return _atRootRule(start);
      case "content":
        return _contentRule(start);
      case "debug":
        return _debugRule(start);
      case "each":
        return _eachRule(start, child);
      case "error":
        return _errorRule(start);
      case "extend":
        return _extendRule(start);
      case "for":
        return _forRule(start, child);
      case "function":
        return _functionRule(start);
      case "if":
        return _ifRule(start, child);
      case "import":
        return _importRule(start);
      case "include":
        return _includeRule(start);
      case "media":
        return _mediaRule(start);
      case "mixin":
        return _mixinRule(start);
      case "return":
        return _disallowedAtRule(start);
      case "supports":
        return _supportsRule(start);
      case "warn":
        return _warnRule(start);
      case "while":
        return _whileRule(start, child);
      default:
        return _unknownAtRule(start, name);
    }
  }

  Statement _declarationAtRule() {
    var start = scanner.state;
    var name = _atRuleName();

    switch (name) {
      case "content":
        return _contentRule(start);
      case "debug":
        return _debugRule(start);
      case "each":
        return _eachRule(start, _declarationChild);
      case "error":
        return _errorRule(start);
      case "for":
        return _forRule(start, _declarationAtRule);
      case "if":
        return _ifRule(start, _declarationChild);
      case "include":
        return _includeRule(start);
      case "warn":
        return _warnRule(start);
      case "while":
        return _whileRule(start, _declarationChild);
      default:
        return _disallowedAtRule(start);
    }
  }

  Statement _functionAtRule() {
    var start = scanner.state;
    switch (_atRuleName()) {
      case "debug":
        return _debugRule(start);
      case "each":
        return _eachRule(start, _functionAtRule);
      case "error":
        return _errorRule(start);
      case "for":
        return _forRule(start, _functionAtRule);
      case "if":
        return _ifRule(start, _functionAtRule);
      case "return":
        return _returnRule(start);
      case "warn":
        return _warnRule(start);
      case "while":
        return _whileRule(start, _functionAtRule);
      default:
        return _disallowedAtRule(start);
    }
  }

  String _atRuleName() {
    scanner.expectChar($at);
    var name = identifier();
    whitespace();
    return name;
  }

  AtRootRule _atRootRule(LineScannerState start) {
    var next = scanner.peekChar();
    var query = next == $hash || next == $lparen ? _queryExpression() : null;
    whitespace();
    return new AtRootRule(children(_topLevelStatement), scanner.spanFrom(start),
        query: query);
  }

  ContentRule _contentRule(LineScannerState start) {
    if (_inMixin) {
      _mixinHasContent = true;
      return new ContentRule(scanner.spanFrom(start));
    }

    scanner.error("@content is only allowed within mixin declarations.",
        position: start.position, length: "@content".length);
    return null;
  }

  DebugRule _debugRule(LineScannerState start) =>
      new DebugRule(_expression(), scanner.spanFrom(start));

  EachRule _eachRule(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;

    var variables = [variableName()];
    whitespace();
    while (scanner.scanChar($comma)) {
      whitespace();
      variables.add(variableName());
      whitespace();
    }

    expectIdentifier("in");
    whitespace();

    var list = _expression();
    var children = this.children(child);
    _inControlDirective = wasInControlDirective;

    return new EachRule(variables, list, children, scanner.spanFrom(start));
  }

  ErrorRule _errorRule(LineScannerState start) =>
      new ErrorRule(_expression(), scanner.spanFrom(start));

  ExtendRule _extendRule(LineScannerState start) {
    var value = _almostAnyValue();
    var optional = scanner.scanChar($exclamation);
    if (optional) expectIdentifier("optional");
    return new ExtendRule(value, scanner.spanFrom(start), optional: optional);
  }

  FunctionRule _functionRule(LineScannerState start) {
    var name = identifier();
    whitespace();
    var arguments = _argumentDeclaration();

    if (_inMixin || _inContentBlock) {
      throw new StringScannerException(
          "Mixins may not contain function declarations.",
          scanner.spanFrom(start),
          scanner.string);
    }

    whitespace();
    var children = this.children(_functionAtRule);

    // TODO: ensure there aren't duplicate argument names.
    return new FunctionRule(name, arguments, children, scanner.spanFrom(start));
  }

  ForRule _forRule(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var variable = variableName();
    whitespace();

    expectIdentifier("from");
    whitespace();

    bool exclusive;
    var from = _expression(until: () {
      if (!lookingAtIdentifier()) return false;
      if (scanIdentifier("to")) {
        exclusive = true;
        return true;
      } else if (scanIdentifier("through")) {
        exclusive = false;
        return true;
      } else {
        return false;
      }
    });
    if (exclusive == null) scanner.error('Expected "to" or "through".');

    whitespace();
    var to = _expression();

    var children = this.children(child);
    _inControlDirective = wasInControlDirective;

    return new ForRule(variable, from, to, children, scanner.spanFrom(start),
        exclusive: exclusive);
  }

  IfRule _ifRule(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var expression = _expression();
    var children = this.children(child);
    _inControlDirective = wasInControlDirective;
    return new IfRule(expression, children, scanner.spanFrom(start));
  }

  Statement _importRule(LineScannerState start) {
    if (_inControlDirective) {
      _disallowedAtRule(start);
      return null;
    }

    // TODO: wrap error with a span
    // TODO: parse supports clauses, url(), and query lists
    var urlString = string();
    var url = Uri.parse(urlString);
    if (_isPlainImportUrl(urlString)) {
      return new PlainImportRule(url, scanner.spanFrom(start));
    } else {
      return new ImportRule(url, scanner.spanFrom(start));
    }
  }

  bool _isPlainImportUrl(String url) {
    if (url.length < "//".length) return false;

    var first = url.codeUnitAt(0);
    if (first == $slash) return url.codeUnitAt(1) == $slash;
    if (first != $h) return false;
    return url.startsWith("http://") || url.startsWith("https://");
  }

  IncludeRule _includeRule(LineScannerState start) {
    var name = identifier();
    whitespace();
    var arguments = scanner.peekChar() == $lparen
        ? _argumentInvocation()
        : new ArgumentInvocation.empty(scanner.emptySpan);
    whitespace();

    List<Statement> children;
    if (lookingAtChildren()) {
      _inContentBlock = true;
      children = this.children(_ruleChild);
      _inContentBlock = false;
    }

    return new IncludeRule(name, arguments, scanner.spanFrom(start),
        children: children);
  }

  MediaRule _mediaRule(LineScannerState start) => new MediaRule(
      _mediaQueryList(), children(_ruleChild), scanner.spanFrom(start));

  MixinRule _mixinRule(LineScannerState start) {
    var name = identifier();
    whitespace();
    var arguments = scanner.peekChar() == $lparen
        ? _argumentDeclaration()
        : new ArgumentDeclaration.empty(span: scanner.emptySpan);

    if (_inMixin || _inContentBlock) {
      throw new StringScannerException(
          "Mixins may not contain mixin declarations.",
          scanner.spanFrom(start),
          scanner.string);
    }

    whitespace();
    _inMixin = true;
    _mixinHasContent = false;
    var children = this.children(_ruleChild);
    _inMixin = false;

    return new MixinRule(name, arguments, children, scanner.spanFrom(start),
        hasContent: _mixinHasContent);
  }

  ReturnRule _returnRule(LineScannerState start) =>
      new ReturnRule(_expression(), scanner.spanFrom(start));

  SupportsRule _supportsRule(LineScannerState start) {
    var condition = _supportsCondition();
    whitespace();
    return new SupportsRule(
        condition, children(_ruleChild), scanner.spanFrom(start));
  }

  WarnRule _warnRule(LineScannerState start) =>
      new WarnRule(_expression(), scanner.spanFrom(start));

  WhileRule _whileRule(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var expression = _expression();
    var children = this.children(child);
    _inControlDirective = wasInControlDirective;
    return new WhileRule(expression, children, scanner.spanFrom(start));
  }

  AtRule _unknownAtRule(LineScannerState start, String name) {
    Interpolation value;
    var next = scanner.peekChar();
    if (next != $exclamation && !atEndOfStatement()) value = _almostAnyValue();

    return new AtRule(name, scanner.spanFrom(start),
        value: value,
        children: lookingAtChildren() ? children(_ruleChild) : null);
  }

  // This returns [Statement] so that it can be returned within case statements.
  Statement _disallowedAtRule(LineScannerState start) {
    _almostAnyValue();
    scanner.error("This at-rule is not allowed here.",
        position: start.position,
        length: scanner.state.position - start.position);
    return null;
  }

  ArgumentDeclaration _argumentDeclaration() {
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();
    var arguments = <Argument>[];
    String restArgument;
    while (scanner.peekChar() == $dollar) {
      var variableStart = scanner.state;
      var name = variableName();
      whitespace();

      Expression defaultValue;
      if (scanner.scanChar($colon)) {
        whitespace();
        defaultValue = _expressionUntilComma();
      } else if (scanner.scanChar($dot)) {
        scanner.expectChar($dot);
        scanner.expectChar($dot);
        restArgument = name;
        break;
      }

      arguments.add(new Argument(name,
          span: scanner.spanFrom(variableStart), defaultValue: defaultValue));
      if (!scanner.scanChar($comma)) break;
      whitespace();
    }
    scanner.expectChar($rparen);
    return new ArgumentDeclaration(arguments,
        restArgument: restArgument, span: scanner.spanFrom(start));
  }

  // ## Expressions

  ArgumentInvocation _argumentInvocation() {
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();

    var positional = <Expression>[];
    var named = <String, Expression>{};
    Expression rest;
    Expression keywordRest;
    while (_lookingAtExpression()) {
      var expression = _expressionUntilComma();
      whitespace();

      if (expression is VariableExpression && scanner.scanChar($colon)) {
        whitespace();
        named[expression.name] = _expressionUntilComma();
      } else if (scanner.scanChar($dot)) {
        scanner.expectChar($dot);
        scanner.expectChar($dot);
        if (rest == null) {
          rest = expression;
        } else {
          keywordRest = expression;
          whitespace();
          break;
        }
      } else if (named.isNotEmpty) {
        scanner.expect("...");
      } else {
        positional.add(expression);
      }

      whitespace();
      if (!scanner.scanChar($comma)) break;
      whitespace();
    }
    scanner.expectChar($rparen);

    return new ArgumentInvocation(positional, named, scanner.spanFrom(start),
        rest: rest, keywordRest: keywordRest);
  }

  Expression _expression({bool until()}) {
    if (until != null && until()) scanner.error("Expected expression.");

    List<Expression> commaExpressions;
    List<Expression> spaceExpressions;

    // Operators whose right-hand operands are not fully parsed yet, in order of
    // appearance in the document. Because a low-precedence operator will cause
    // parsing to finish for all preceding higher-precedence operators, this is
    // naturally ordered from lowest to highest precedence.
    List<BinaryOperator> operators;

    // The left-hand sides of [operators]. `operands[n]` is the left-hand side
    // of `operators[n]`.
    List<Expression> operands;
    var singleExpression = _singleExpression();

    resolveOneOperation() {
      assert(singleExpression != null);
      singleExpression = new BinaryOperationExpression(
          operators.removeLast(), operands.removeLast(), singleExpression);
    }

    resolveOperations() {
      if (operators == null) return;
      while (!operators.isEmpty) {
        resolveOneOperation();
      }
    }

    addSingleExpression(Expression expression) {
      if (singleExpression != null) {
        spaceExpressions ??= [];
        resolveOperations();
        spaceExpressions.add(singleExpression);
      }
      singleExpression = expression;
    }

    addOperator(BinaryOperator operator) {
      operators ??= [];
      operands ??= [];
      while (operators.isNotEmpty &&
          operators.last.precedence >= operator.precedence) {
        resolveOneOperation();
      }
      operators.add(operator);

      assert(singleExpression != null);
      operands.add(singleExpression);
      singleExpression = null;
    }

    resolveSpaceExpressions() {
      if (singleExpression != null) resolveOperations();
      if (spaceExpressions == null) return;
      if (singleExpression != null) spaceExpressions.add(singleExpression);
      singleExpression =
          new ListExpression(spaceExpressions, ListSeparator.space);
      spaceExpressions = null;
    }

    loop:
    while (true) {
      whitespace();
      if (until != null && until()) break;

      var first = scanner.peekChar();
      switch (first) {
        case $lparen:
          addSingleExpression(_parentheses());
          break;

        case $lbracket:
          addSingleExpression(_bracketedList());
          break;

        case $dollar:
          addSingleExpression(_variable());
          break;

        case $ampersand:
          addSingleExpression(_selector());
          break;

        case $single_quote:
        case $double_quote:
          addSingleExpression(interpolatedString());
          break;

        case $hash:
          addSingleExpression(_hashExpression());
          break;

        case $equal:
          scanner.readChar();
          scanner.expectChar($equal);
          addOperator(BinaryOperator.equals);
          break;

        case $exclamation:
          scanner.readChar();
          scanner.expectChar($equal);
          addOperator(BinaryOperator.notEquals);
          break;

        case $langle:
          scanner.readChar();
          addOperator(scanner.scanChar($equal)
              ? BinaryOperator.lessThanOrEquals
              : BinaryOperator.lessThan);
          break;

        case $rangle:
          scanner.readChar();
          addOperator(scanner.scanChar($equal)
              ? BinaryOperator.greaterThanOrEquals
              : BinaryOperator.greaterThan);
          break;

        case $asterisk:
          scanner.readChar();
          addOperator(BinaryOperator.times);
          break;

        case $plus:
          scanner.readChar();
          addOperator(BinaryOperator.plus);
          break;

        case $minus:
          var next = scanner.peekChar(1);
          if (isDigit(next) || next == $dot) {
            addSingleExpression(_number());
          } else if (_lookingAtInterpolatedIdentifier()) {
            addSingleExpression(_identifierLike());
          } else {
            addOperator(BinaryOperator.minus);
          }
          break;

        case $slash:
          scanner.readChar();
          addOperator(BinaryOperator.dividedBy);
          break;

        case $percent:
          scanner.readChar();
          addOperator(BinaryOperator.modulo);
          break;

        case $0:
        case $1:
        case $2:
        case $3:
        case $4:
        case $5:
        case $6:
        case $7:
        case $8:
        case $9:
          addSingleExpression(_number());
          break;

        case $dot:
          if (scanner.peekChar(1) == $dot) break loop;
          addSingleExpression(_number());
          break;

        case $a:
          if (scanIdentifier("and")) {
            addOperator(BinaryOperator.and);
          } else {
            addSingleExpression(_identifierLike());
          }
          break;

        case $o:
          if (scanIdentifier("or")) {
            addOperator(BinaryOperator.and);
          } else {
            addSingleExpression(_identifierLike());
          }
          break;

        case $b:
        case $c:
        case $d:
        case $e:
        case $f:
        case $g:
        case $h:
        case $i:
        case $j:
        case $k:
        case $l:
        case $m:
        case $n:
        case $p:
        case $q:
        case $r:
        case $s:
        case $t:
        case $u:
        case $v:
        case $w:
        case $x:
        case $y:
        case $z:
        case $A:
        case $B:
        case $C:
        case $D:
        case $E:
        case $F:
        case $G:
        case $H:
        case $I:
        case $J:
        case $K:
        case $L:
        case $M:
        case $N:
        case $O:
        case $P:
        case $Q:
        case $R:
        case $S:
        case $T:
        case $U:
        case $V:
        case $W:
        case $X:
        case $Y:
        case $Z:
        case $_:
        case $backslash:
          addSingleExpression(_identifierLike());
          break;

        case $comma:
          commaExpressions ??= [];
          if (singleExpression == null) scanner.error("Expected expression.");

          resolveSpaceExpressions();
          commaExpressions.add(singleExpression);
          scanner.readChar();
          singleExpression = null;
          break;

        default:
          if (first != null && first >= 0x80) {
            addSingleExpression(_identifierLike());
            break;
          } else {
            break loop;
          }
      }
    }

    resolveSpaceExpressions();
    if (commaExpressions != null) {
      if (singleExpression != null) commaExpressions.add(singleExpression);
      return new ListExpression(commaExpressions, ListSeparator.comma);
    } else {
      assert(singleExpression != null);
      return singleExpression;
    }
  }

  Expression _expressionUntilComma() =>
      _expression(until: () => scanner.peekChar() == $comma);

  // non-list expression
  Expression _singleExpression() {
    var first = scanner.peekChar();
    switch (first) {
      // Note: when adding a new case, make sure it's reflected in
      // [_lookingAtExpression] and [_expression].
      case $lparen:
        return _parentheses();
      case $slash:
        return _unaryOperation();
      case $dot:
        return _number();
      case $lbracket:
        return _bracketedList();
      case $dollar:
        return _variable();
      case $ampersand:
        return _selector();

      case $single_quote:
      case $double_quote:
        return interpolatedString();

      case $hash:
        return _hashExpression();

      case $plus:
        return _plusExpression();

      case $minus:
        return _minusExpression();

      case $0:
      case $1:
      case $2:
      case $3:
      case $4:
      case $5:
      case $6:
      case $7:
      case $8:
      case $9:
        return _number();
        break;

      case $a:
      case $b:
      case $c:
      case $d:
      case $e:
      case $f:
      case $g:
      case $h:
      case $i:
      case $j:
      case $k:
      case $l:
      case $m:
      case $n:
      case $o:
      case $p:
      case $q:
      case $r:
      case $s:
      case $t:
      case $u:
      case $v:
      case $w:
      case $x:
      case $y:
      case $z:
      case $A:
      case $B:
      case $C:
      case $D:
      case $E:
      case $F:
      case $G:
      case $H:
      case $I:
      case $J:
      case $K:
      case $L:
      case $M:
      case $N:
      case $O:
      case $P:
      case $Q:
      case $R:
      case $S:
      case $T:
      case $U:
      case $V:
      case $W:
      case $X:
      case $Y:
      case $Z:
      case $_:
      case $backslash:
        return _identifierLike();
        break;

      default:
        if (first != null && first >= 0x80) return _identifierLike();
        scanner.error("Expected expression.");
        return null;
    }
  }

  ListExpression _bracketedList() {
    var start = scanner.state;
    scanner.expectChar($lbracket);
    whitespace();

    var expressions = <Expression>[];
    while (!scanner.scanChar($lbracket)) {
      expressions.add(_expressionUntilComma());
      whitespace();
      if (!scanner.scanChar($comma)) break;
    }

    return new ListExpression(expressions, ListSeparator.comma,
        brackets: true, span: scanner.spanFrom(start));
  }

  Expression _parentheses() {
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();
    if (!_lookingAtExpression()) {
      scanner.expectChar($rparen);
      return new ListExpression([], ListSeparator.undecided,
          span: scanner.spanFrom(start));
    }

    var first = _expressionUntilComma();
    if (scanner.scanChar($colon)) {
      whitespace();
      return _map(first, start);
    }

    if (!scanner.scanChar($comma)) {
      scanner.expectChar($rparen);
      return first;
    }
    whitespace();

    var expressions = [first];
    while (true) {
      if (!_lookingAtExpression()) break;
      expressions.add(_expressionUntilComma());
      if (!scanner.scanChar($comma)) break;
      whitespace();
    }

    scanner.expectChar($rparen);
    return new ListExpression(expressions, ListSeparator.comma,
        span: scanner.spanFrom(start));
  }

  MapExpression _map(Expression first, LineScannerState start) {
    var pairs = [new Tuple2(first, _expressionUntilComma())];

    while (scanner.scanChar($comma)) {
      whitespace();
      if (!_lookingAtExpression()) break;

      var key = _expressionUntilComma();
      scanner.expectChar($colon);
      whitespace();
      var value = _expressionUntilComma();
      pairs.add(new Tuple2(key, value));
    }

    scanner.expectChar($rparen);
    return new MapExpression(pairs, scanner.spanFrom(start));
  }

  Expression _hashExpression() {
    assert(scanner.peekChar() == $hash);
    return scanner.peekChar(1) == $lbrace ? _identifierLike() : _hexColorOrID();
  }

  Expression _plusExpression() {
    assert(scanner.peekChar() == $plus);
    var next = scanner.peekChar(1);
    return isDigit(next) || next == $dot ? _number() : _unaryOperation();
  }

  Expression _minusExpression() {
    assert(scanner.peekChar() == $minus);
    var next = scanner.peekChar(1);
    if (isDigit(next) || next == $dot) return _number();
    if (_lookingAtInterpolatedIdentifier()) return _identifierLike();
    return _unaryOperation();
  }

  UnaryOperationExpression _unaryOperation() {
    var start = scanner.state;
    var operator = _unaryOperatorFor(scanner.readChar());
    if (operator == null) {
      scanner.error("Expected unary operator", position: scanner.position - 1);
    }

    whitespace();
    var operand = _singleExpression();
    return new UnaryOperationExpression(
        operator, operand, scanner.spanFrom(start));
  }

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

  NumberExpression _number() {
    var start = scanner.state;
    var first = scanner.peekChar();
    var sign = first == $dash ? -1 : 1;
    if (first == $plus || first == $minus) scanner.readChar();

    num number = 0;
    var second = scanner.peekChar();
    if (!isDigit(second) && second != $dot) scanner.error("Expected number.");

    while (isDigit(scanner.peekChar())) {
      number *= 10;
      number += scanner.readChar() - $0;
    }

    if (scanner.peekChar() == $dot) {
      scanner.readChar();
      if (!isDigit(scanner.peekChar())) scanner.error("Expected digit.");

      var decimal = 0.1;
      while (isDigit(scanner.peekChar())) {
        number += (scanner.readChar() - $0) * decimal;
        decimal /= 10;
      }
    }

    if (scanIdentifier("e", ignoreCase: true)) {
      scanner.readChar();
      var next = scanner.peekChar();
      var exponentSign = next == $dash ? -1 : 1;
      if (next == $plus || next == $minus) scanner.readChar();
      if (!isDigit(scanner.peekChar())) scanner.error("Expected digit.");

      var exponent = 0.0;
      while (isDigit(scanner.peekChar())) {
        exponent *= 10;
        exponent += scanner.readChar() - $0;
      }

      number = number * math.pow(10, exponentSign * exponent);
    }

    String unit;
    if (scanner.scanChar($percent)) {
      unit = "%";
    } else if (lookingAtIdentifier()) {
      unit = identifier();
    }

    return new NumberExpression(sign * number, scanner.spanFrom(start),
        unit: unit);
  }

  VariableExpression _variable() {
    var start = scanner.state;
    return new VariableExpression(variableName(), scanner.spanFrom(start));
  }

  SelectorExpression _selector() {
    var start = scanner.state;
    scanner.expectChar($ampersand);
    return new SelectorExpression(scanner.spanFrom(start));
  }

  StringExpression interpolatedString() {
    // NOTE: this logic is largely duplicated in ScssParser.interpolatedString.
    // Most changes here should be mirrored there.

    var start = scanner.state;
    var quote = scanner.readChar();

    if (quote != $single_quote && quote != $double_quote) {
      scanner.error("Expected string.", position: start.position);
    }

    var buffer = new InterpolationBuffer();
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
          buffer.writeCharCode(escape());
        }
      } else if (next == $hash) {
        if (scanner.peekChar(1) == $lbrace) {
          buffer.add(singleInterpolation());
        } else {
          buffer.writeCharCode(scanner.readChar());
        }
      } else {
        buffer.writeCharCode(scanner.readChar());
      }
    }

    return new StringExpression(buffer.interpolation(scanner.spanFrom(start)),
        quotes: true);
  }

  Expression _hexColorOrID() {
    var start = scanner.state;
    scanner.expectChar($hash);

    var first = scanner.peekChar();
    if (first != null && isDigit(first)) {
      return new ColorExpression(_hexColorContents(), scanner.spanFrom(start));
    }

    var afterHash = scanner.state;
    var identifier = _interpolatedIdentifier();
    if (_isHexColor(identifier)) {
      scanner.state = afterHash;
      return new ColorExpression(_hexColorContents(), scanner.spanFrom(start));
    }

    var buffer = new InterpolationBuffer();
    buffer.writeCharCode($hash);
    buffer.addInterpolation(identifier);
    return new StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  SassColor _hexColorContents() {
    var red = _hexDigit();
    var green = _hexDigit();
    var blue = _hexDigit();

    var next = scanner.peekChar();
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

  int _hexDigit() {
    var char = scanner.peekChar();
    if (char == null || !isHex(char)) scanner.error("Expected hex digit.");
    return asHex(scanner.readChar());
  }

  Expression _identifierLike() {
    // TODO: url()
    var identifier = _interpolatedIdentifier();
    switch (identifier.asPlain) {
      case "false":
        return new BooleanExpression(false, identifier.span);
      case "if":
        var invocation = _argumentInvocation();
        return new IfExpression(
            invocation, spanForList([identifier, invocation]));
      case "not":
        whitespace();
        return new UnaryOperationExpression(
            UnaryOperator.not, _singleExpression(), identifier.span);
      case "null":
        return new NullExpression(identifier.span);
      case "true":
        return new BooleanExpression(true, identifier.span);
    }

    return scanner.peekChar() == $lparen
        ? new FunctionExpression(identifier, _argumentInvocation())
        : new StringExpression(identifier);
  }

  /// Consumes tokens up to "{", "}", ";", or "!".
  ///
  /// This respects string and comment boundaries and supports interpolation.
  /// Once this interpolation is evaluated, it's expected to be re-parsed.
  ///
  /// Differences from [_interpolatedDeclarationValue] include:
  ///
  /// * This does not balance brackets.
  ///
  /// * This does not interpret backslashes, since the text is expected to be
  ///   re-parsed.
  ///
  /// * This supports Sass-style single-line comments.
  ///
  /// * This does not compress adjacent whitespace characters.
  Interpolation _almostAnyValue() {
    var start = scanner.state;
    var buffer = new InterpolationBuffer();

    loop:
    while (true) {
      var next = scanner.peekChar();
      switch (next) {
        case $backslash:
          // Write a literal backslash because this text will be re-parsed.
          buffer.writeCharCode(scanner.readChar());
          buffer.writeCharCode(scanner.readChar());
          break;

        case $double_quote:
        case $single_quote:
          buffer.addInterpolation(interpolatedString().asInterpolation());
          break;

        case $slash:
          var commentStart = scanner.position;
          if (comment()) {
            buffer.write(scanner.substring(commentStart));
          } else {
            buffer.write(scanner.readChar());
          }
          break;

        case $hash:
          if (scanner.peekChar(1) == $lbrace) {
            buffer.add(singleInterpolation());
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          break;

        case $cr:
        case $lf:
        case $ff:
          if (indented) break loop;
          buffer.writeCharCode(scanner.readChar());
          break;

        case $exclamation:
        case $semicolon:
        case $lbrace:
        case $rbrace:
          break loop;

        default:
          if (next == null) break loop;

          // TODO: support url()
          buffer.writeCharCode(scanner.readChar());
          break;
      }
    }

    return buffer.interpolation(scanner.spanFrom(start));
  }

  StringExpression _interpolatedDeclarationValue() {
    // NOTE: this logic is largely duplicated in Parser.declarationValue. Most
    // changes here should be mirrored there.

    var start = scanner.state;
    var buffer = new InterpolationBuffer();

    var brackets = <int>[];
    var wroteNewline = false;
    loop:
    while (true) {
      var next = scanner.peekChar();
      switch (next) {
        case $backslash:
          buffer.writeCharCode(escape());
          wroteNewline = false;
          break;

        case $double_quote:
        case $single_quote:
          buffer.addInterpolation(interpolatedString().asInterpolation());
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

        case $hash:
          if (scanner.peekChar(1) == $lbrace) {
            buffer.add(singleInterpolation());
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
          if (indented) break loop;
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

        default:
          if (next == null) break loop;

          // TODO: support url()
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;
          break;
      }
    }

    if (brackets.isNotEmpty) scanner.expectChar(brackets.last);
    return new StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  Interpolation _interpolatedIdentifier() {
    var start = scanner.state;
    var buffer = new InterpolationBuffer();

    while (scanner.scanChar($dash)) {
      buffer.writeCharCode($dash);
    }

    var first = scanner.peekChar();
    if (first == null) {
      scanner.error("Expected identifier.");
    } else if (isNameStart(first)) {
      buffer.writeCharCode(scanner.readChar());
    } else if (first == $backslash) {
      buffer.writeCharCode(escape());
    } else if (first == $hash && scanner.peekChar(1) == $lbrace) {
      buffer.add(singleInterpolation());
    }

    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $underscore ||
          next == $dash ||
          isAlphanumeric(next) ||
          next >= 0x0080) {
        buffer.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        buffer.writeCharCode(escape());
      } else if (next == $hash && scanner.peekChar(1) == $lbrace) {
        buffer.add(singleInterpolation());
      } else {
        break;
      }
    }

    return buffer.interpolation(scanner.spanFrom(start));
  }

  Expression singleInterpolation() {
    scanner.expect('#{');
    whitespace();
    var expression = _expression();
    scanner.expectChar($rbrace);
    return expression;
  }

  /// A query expression of the form `(foo: bar)`.
  Interpolation _queryExpression() {
    if (scanner.peekChar() == $hash) {
      var interpolation = singleInterpolation();
      return new Interpolation([interpolation], interpolation.span);
    }

    var start = scanner.state;
    var buffer = new InterpolationBuffer();
    scanner.expectChar($lparen);
    buffer.writeCharCode($lparen);
    whitespace();

    buffer.add(_expression());
    if (scanner.scanChar($colon)) {
      whitespace();
      buffer.writeCharCode($colon);
      buffer.writeCharCode($space);
      buffer.add(_expression());
    }

    scanner.expectChar($rparen);
    whitespace();
    buffer.writeCharCode($rparen);

    return buffer.interpolation(scanner.spanFrom(start));
  }

  // ## Media Queries

  List<MediaQuery> _mediaQueryList() {
    var queries = <MediaQuery>[];
    do {
      whitespace();
      queries.add(_mediaQuery());
    } while (scanner.scanChar($comma));
    return queries;
  }

  MediaQuery _mediaQuery() {
    Interpolation modifier;
    Interpolation type;
    if (scanner.peekChar() != $lparen) {
      var identifier1 = _interpolatedIdentifier();
      whitespace();

      if (!_lookingAtInterpolatedIdentifier()) {
        // For example, "@media screen {"
        return new MediaQuery(identifier1);
      }

      var identifier2 = _interpolatedIdentifier();
      whitespace();

      if (equalsIgnoreCase(identifier2.asPlain, "and")) {
        // For example, "@media screen and ..."
        type = identifier1;
      } else {
        modifier = identifier1;
        type = identifier2;
        if (scanIdentifier("and", ignoreCase: true)) {
          // For example, "@media only screen and ..."
          whitespace();
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
      whitespace();
      features.add(_queryExpression());
      whitespace();
    } while (scanIdentifier("and", ignoreCase: true));

    if (type == null) {
      return new MediaQuery.condition(features);
    } else {
      return new MediaQuery(type, modifier: modifier, features: features);
    }
  }

  // ## Supports Conditions

  SupportsCondition _supportsCondition() {
    var start = scanner.state;
    var first = scanner.peekChar();
    if (first != $lparen && first != $hash) {
      var start = scanner.state;
      expectIdentifier("not", ignoreCase: true);
      whitespace();
      return new SupportsNegation(
          _supportsConditionInParens(), scanner.spanFrom(start));
    }

    var condition = _supportsConditionInParens();
    whitespace();
    while (lookingAtIdentifier()) {
      String operator;
      if (scanIdentifier("or", ignoreCase: true)) {
        operator = "or";
      } else {
        expectIdentifier("and", ignoreCase: true);
        operator = "and";
      }

      whitespace();
      var right = _supportsConditionInParens();
      condition = new SupportsOperation(
          condition, right, operator, scanner.spanFrom(start));
      whitespace();
    }
    return condition;
  }

  SupportsCondition _supportsConditionInParens() {
    var start = scanner.state;
    if (scanner.peekChar() == $hash) {
      return new SupportsInterpolation(
          singleInterpolation(), scanner.spanFrom(start));
    }

    scanner.expectChar($lparen);
    whitespace();
    var next = scanner.peekChar();
    if (next == $lparen || next == $hash) {
      var condition = _supportsCondition();
      whitespace();
      scanner.expectChar($rparen);
      return condition;
    }

    if (next == $n || next == $N) {
      var negation = _trySupportsNegation();
      if (negation != null) return negation;
    }

    var name = _expression();
    scanner.expectChar($colon);
    whitespace();
    var value = _expression();
    scanner.expectChar($rparen);
    return new SupportsDeclaration(name, value, scanner.spanFrom(start));
  }

  // If this fails, it puts the cursor back at the beginning.
  SupportsNegation _trySupportsNegation() {
    var start = scanner.state;
    if (!scanIdentifier("not", ignoreCase: true) || scanner.isDone) {
      scanner.state = start;
      return null;
    }

    var next = scanner.peekChar();
    if (!isWhitespace(next) && next != $lparen) {
      scanner.state = start;
      return null;
    }

    return new SupportsNegation(
        _supportsConditionInParens(), scanner.spanFrom(start));
  }

  // ## Characters

  /// This is based on [the CSS algorithm][], but it assumes all backslashes
  /// start escapes and it considers interpolation to be valid in an identifier.
  ///
  /// [the CSS algorithm]: https://drafts.csswg.org/css-syntax-3/#would-start-an-identifier
  bool _lookingAtInterpolatedIdentifier() {
    // See also [ScssParser._lookingAtIdentifier].

    var first = scanner.peekChar();
    if (first == null) return false;
    if (isNameStart(first) || first == $backslash) return true;
    if (first == $hash) return scanner.peekChar(1) == $lbrace;

    if (first != $dash) return false;
    var second = scanner.peekChar(1);
    if (isNameStart(second) || second == $dash || second == $backslash) {
      return true;
    }
    return second == $hash && scanner.peekChar(2) == $lbrace;
  }

  bool _lookingAtExpression() {
    var character = scanner.peekChar();
    if (character == null) return false;
    if (character == $dot) return scanner.peekChar(1) != $dot;

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
        character == $ampersand ||
        isNameStart(character) ||
        isDigit(character);
  }

  // ## Abstract Methods

  bool get indented;

  bool atEndOfStatement();

  bool lookingAtChildren();

  List<Statement> children(Statement child());
  List<Statement> statements(Statement statement());
}
