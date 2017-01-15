// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../color_names.dart';
import '../interpolation_buffer.dart';
import '../util/character.dart';
import '../utils.dart';
import '../value.dart';
import '../value/color.dart';
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
  /// Whether the parser is currently parsing the contents of a mixin
  /// declaration.
  var _inMixin = false;

  /// Whether the current mixin contains at least one `@content` rule.
  ///
  /// This is `null` unless [_inMixin] is `true`.
  bool _mixinHasContent;

  /// Whether the parser is currently parsing a content block passed to a mixin.
  var _inContentBlock = false;

  /// Whether the parser is currently parsing a control directive such as `@if`
  /// or `@each`.
  var _inControlDirective = false;

  /// Whether the parser is currently within a parenthesized expression.
  var _inParentheses = false;

  /// Whether warnings should be emitted using terminal colors.
  ///
  /// This is protected and shouldn't be accessed except by subclasses.
  final bool color;

  StylesheetParser(String contents, {url, this.color: false})
      : super(contents, url: url);

  // ## Statements

  Stylesheet parse() {
    return wrapSpanFormatException(() {
      var start = scanner.state;
      var statements = this.statements(() => _statement(root: true));
      scanner.expectDone();
      return new Stylesheet(statements, scanner.spanFrom(start));
    });
  }

  ArgumentDeclaration parseArgumentDeclaration() {
    return wrapSpanFormatException(() {
      var declaration = _argumentDeclaration();
      scanner.expectDone();
      return declaration;
    });
  }

  /// Consumes a statement that's allowed at the top level of the stylesheet or
  /// within nested style and at rules.
  ///
  /// If [root] is `true`, this parses at-rules that are allowed only at the
  /// root of the stylesheet.
  Statement _statement({bool root: false}) {
    switch (scanner.peekChar()) {
      case $at:
        return _atRule(() => _statement(), root: root);

      case $plus:
        if (!indented || !lookingAtIdentifier(1)) return _styleRule();
        var start = scanner.state;
        scanner.readChar();
        return _includeRule(start);

      case $equal:
        if (!indented) return _styleRule();
        var start = scanner.state;
        scanner.readChar();
        whitespace();
        return _mixinRule(start);

      default:
        return root ? _styleRule() : _declarationOrStyleRule();
    }
  }

  /// Consumes a variable declaration.
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

    expectStatementSeparator("variable declaration");
    return new VariableDeclaration(name, expression, scanner.spanFrom(start),
        guarded: guarded, global: global);
  }

  /// Consumes a style rule.
  StyleRule _styleRule() {
    var start = scanner.state;
    var selector = _almostAnyValue();
    var children = this.children(_statement);
    return new StyleRule(selector, children, scanner.spanFrom(start));
  }

  /// Consumes a [Declaration] or a [StyleRule].
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

    var children = this.children(_statement);
    if (indented && children.isEmpty) {
      warn("This selector doesn't have any properties and won't be rendered.",
          selectorSpan,
          color: color);
    }

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
    if (!scanner.scanChar($colon)) {
      if (midBuffer.isNotEmpty) nameBuffer.writeCharCode($space);
      return nameBuffer;
    }
    midBuffer.writeCharCode($colon);

    // Parse custom properties as declarations no matter what.
    var name = nameBuffer.interpolation(scanner.spanFrom(start));
    if (name.initialPlain.startsWith('--')) {
      var value = _interpolatedDeclarationValue();
      expectStatementSeparator("custom property");
      return new Declaration(name, scanner.spanFrom(start), value: value);
    }

    if (scanner.scanChar($colon)) {
      return nameBuffer
        ..write(midBuffer)
        ..writeCharCode($colon);
    } else if (indented && _lookingAtInterpolatedIdentifier()) {
      // In the indented syntax, `foo:bar` is always considered a selector
      // rather than a property.
      return nameBuffer..write(midBuffer);
    }

    var postColonWhitespace = rawText(whitespace);
    if (lookingAtChildren()) {
      return new Declaration(name, scanner.spanFrom(start),
          children: this.children(_declarationChild));
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

    var children =
        lookingAtChildren() ? this.children(_declarationChild) : null;
    if (children == null) expectStatementSeparator();

    return new Declaration(name, scanner.spanFrom(start),
        value: value, children: children);
  }

  /// Consumes a property declaration.
  ///
  /// This is only used in contexts where declarations are allowed but style
  /// rules are not, such as nested declarations. Otherwise,
  /// [_declarationOrStyleRule] is used instead.
  Declaration _declaration() {
    var start = scanner.state;
    var name = _interpolatedIdentifier();
    whitespace();
    scanner.expectChar($colon);
    whitespace();

    if (lookingAtChildren()) {
      return new Declaration(name, scanner.spanFrom(start),
          children: this.children(_declarationChild));
    }

    var value = _declarationExpression();
    var children =
        lookingAtChildren() ? this.children(_declarationChild) : null;
    if (children == null) expectStatementSeparator();
    return new Declaration(name, scanner.spanFrom(start),
        value: value, children: children);
  }

  /// Consumes an expression after a property declaration.
  ///
  /// This parses an empty identifier expression if the declaration has no value
  /// but has children.
  Expression _declarationExpression() {
    if (lookingAtChildren()) {
      return new StringExpression(new Interpolation([], scanner.emptySpan),
          quotes: true);
    }

    return _expression();
  }

  /// Consumes a statement that's allowed within a declaration.
  Statement _declarationChild() {
    if (scanner.peekChar() == $at) return _declarationAtRule();
    return _declaration();
  }

  // ## At Rules

  /// Consumes an at-rule.
  ///
  /// This consumes at-rules that are allowed at all levels of the document; the
  /// [child] parameter is called to consume any at-rules that are specifically
  /// allowed in the caller's context.
  ///
  /// If [root] is `true`, this parses at-rules that are allowed only at the
  /// root of the stylesheet.
  Statement _atRule(Statement child(), {bool root: false}) {
    var start = scanner.state;
    var name = _atRuleName();

    switch (name) {
      case "at-root":
        return _atRootRule(start);
      case "charset":
        if (!root) _disallowedAtRule(start);
        string();
        return null;
      case "content":
        return _contentRule(start);
      case "debug":
        return _debugRule(start);
      case "each":
        return _eachRule(start, child);
      case "else":
        return _disallowedAtRule(start);
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
      case "-moz-document":
        return _mozDocumentRule(start);
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

  /// Consumes an at-rule allowed within a property declaration.
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
      case "else":
        return _disallowedAtRule(start);
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

  /// Consumes an at-rule allowed within a function.
  Statement _functionAtRule() {
    var start = scanner.state;
    switch (_atRuleName()) {
      case "debug":
        return _debugRule(start);
      case "each":
        return _eachRule(start, _functionAtRule);
      case "else":
        return _disallowedAtRule(start);
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

  /// Consumes an at-rule's name.
  String _atRuleName() {
    scanner.expectChar($at);
    var name = identifier();
    whitespace();
    return name;
  }

  /// Consumes an `@at-root` rule.
  ///
  /// [start] should point before the `@`.
  AtRootRule _atRootRule(LineScannerState start) {
    if (scanner.peekChar() == $lparen) {
      var query = _queryExpression();
      whitespace();
      return new AtRootRule(children(_statement), scanner.spanFrom(start),
          query: query);
    } else if (lookingAtChildren()) {
      return new AtRootRule(children(_statement), scanner.spanFrom(start));
    } else {
      var child = _styleRule();
      return new AtRootRule([child], scanner.spanFrom(start));
    }
  }

  /// Consumes a `@content` rule.
  ///
  /// [start] should point before the `@`.
  ContentRule _contentRule(LineScannerState start) {
    if (_inMixin) {
      _mixinHasContent = true;
      expectStatementSeparator("@content rule");
      return new ContentRule(scanner.spanFrom(start));
    }

    scanner.error("@content is only allowed within mixin declarations.",
        position: start.position, length: "@content".length);
    return null;
  }

  /// Consumes a `@debug` rule.
  ///
  /// [start] should point before the `@`.
  DebugRule _debugRule(LineScannerState start) {
    var expression = _expression();
    expectStatementSeparator("@debug rule");
    return new DebugRule(expression, scanner.spanFrom(start));
  }

  /// Consumes an `@each` rule.
  ///
  /// [start] should point before the `@`. [child] is called to consume any
  /// children that are specifically allowed in the caller's context.
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

  /// Consumes an `@error` rule.
  ///
  /// [start] should point before the `@`.
  ErrorRule _errorRule(LineScannerState start) {
    var expression = _expression();
    expectStatementSeparator("@error rule");
    return new ErrorRule(expression, scanner.spanFrom(start));
  }

  /// Consumes an `@extend` rule.
  ///
  /// [start] should point before the `@`.
  ExtendRule _extendRule(LineScannerState start) {
    var value = _almostAnyValue();
    var optional = scanner.scanChar($exclamation);
    if (optional) expectIdentifier("optional");
    expectStatementSeparator("@extend rule");
    return new ExtendRule(value, scanner.spanFrom(start), optional: optional);
  }

  /// Consumes a function declaration.
  ///
  /// [start] should point before the `@`.
  FunctionRule _functionRule(LineScannerState start) {
    var name = identifier();
    whitespace();
    var arguments = _argumentDeclaration();

    if (_inMixin || _inContentBlock) {
      throw new StringScannerException(
          "Mixins may not contain function declarations.",
          scanner.spanFrom(start),
          scanner.string);
    } else if (_inControlDirective) {
      throw new StringScannerException(
          "Functions may not be declared in control directives.",
          scanner.spanFrom(start),
          scanner.string);
    }

    switch (unvendor(name)) {
      case "calc":
      case "element":
      case "expression":
      case "url":
      case "and":
      case "or":
      case "not":
        scanner.error("Invalid function name.",
            position: start.position,
            length: scanner.position - start.position);
        break;
    }

    whitespace();
    var children = this.children(_functionAtRule);

    return new FunctionRule(name, arguments, children, scanner.spanFrom(start));
  }

  /// Consumes a `@for` rule.
  ///
  /// [start] should point before the `@`. [child] is called to consume any
  /// children that are specifically allowed in the caller's context.
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

  /// Consumes an `@if` rule.
  ///
  /// [start] should point before the `@`. [child] is called to consume any
  /// children that are specifically allowed in the caller's context.
  IfRule _ifRule(LineScannerState start, Statement child()) {
    var ifIndentation = currentIndentation;
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var expression = _expression();
    var children = this.children(child);

    var clauses = [new Tuple2(expression, children)];
    List<Statement> lastClause;

    while (scanElse(ifIndentation)) {
      whitespace();
      if (scanIdentifier("if")) {
        whitespace();
        clauses.add(new Tuple2(_expression(), this.children(child)));
      } else {
        lastClause = this.children(child);
        break;
      }
    }
    _inControlDirective = wasInControlDirective;

    return new IfRule(clauses, scanner.spanFrom(start), lastClause: lastClause);
  }

  /// Consumes an `@import` rule.
  ///
  /// [start] should point before the `@`.
  ImportRule _importRule(LineScannerState start) {
    var imports = <Import>[];
    do {
      whitespace();
      imports.add(_importArgument(start));
      whitespace();
    } while (scanner.scanChar($comma));
    expectStatementSeparator("@import rule");

    return new ImportRule(imports, scanner.spanFrom(start));
  }

  /// Consumes an argument to an `@import` rule.
  ///
  /// [ruleStart] should point before the `@`.
  Import _importArgument(LineScannerState ruleStart) {
    var start = scanner.state;
    var next = scanner.peekChar();
    if (next == $u || next == $U) {
      var url = _dynamicUrl();
      whitespace();
      var queries = _tryImportQueries();
      return new StaticImport(new Interpolation([url], scanner.spanFrom(start)),
          scanner.spanFrom(start),
          supports: queries?.item1, media: queries?.item2);
    }

    var url = string();
    var urlSpan = scanner.spanFrom(start);
    whitespace();
    var queries = _tryImportQueries();
    if (_isPlainImportUrl(url) || queries != null) {
      return new StaticImport(
          new Interpolation([urlSpan.text], urlSpan), scanner.spanFrom(start),
          supports: queries?.item1, media: queries?.item2);
    } else if (_inControlDirective || _inMixin) {
      _disallowedAtRule(ruleStart);
      return null;
    } else {
      try {
        return new DynamicImport(Uri.parse(url), urlSpan);
      } on FormatException catch (error) {
        throw new SassFormatException("Invalid URL: ${error.message}", urlSpan);
      }
    }
  }

  /// Returns whether [url] indicates that an `@import` is a plain CSS import.
  bool _isPlainImportUrl(String url) {
    if (url.length < 5) return false;
    if (url.endsWith(".css")) return true;

    var first = url.codeUnitAt(0);
    if (first == $slash) return url.codeUnitAt(1) == $slash;
    if (first != $h) return false;
    return url.startsWith("http://") || url.startsWith("https://");
  }

  /// Consumes a supports condition and/or a media query after an `@import`.
  ///
  /// Returns `null` if neither type of query can be found.
  Tuple2<SupportsCondition, Interpolation> _tryImportQueries() {
    SupportsCondition supports;
    if (scanIdentifier("supports", ignoreCase: true)) {
      scanner.expectChar($lparen);
      var start = scanner.state;
      if (scanIdentifier("not", ignoreCase: true)) {
        whitespace();
        supports = new SupportsNegation(
            _supportsConditionInParens(), scanner.spanFrom(start));
      } else if (scanner.peekChar() == $lparen) {
        supports = _supportsCondition();
      } else {
        var name = _expression();
        scanner.expectChar($colon);
        whitespace();
        var value = _expression();
        supports =
            new SupportsDeclaration(name, value, scanner.spanFrom(start));
      }
      scanner.expectChar($rparen);
      whitespace();
    }

    var media =
        _lookingAtInterpolatedIdentifier() || scanner.peekChar() == $lparen
            ? _mediaQueryList()
            : null;
    if (supports == null && media == null) return null;
    return new Tuple2(supports, media);
  }

  /// Consumes an `@include` rule.
  ///
  /// [start] should point before the `@`.
  IncludeRule _includeRule(LineScannerState start) {
    var name = identifier();
    whitespace();
    var arguments = scanner.peekChar() == $lparen
        ? _argumentInvocation(mixin: true)
        : new ArgumentInvocation.empty(scanner.emptySpan);
    whitespace();

    List<Statement> children;
    if (lookingAtChildren()) {
      _inContentBlock = true;
      children = this.children(_statement);
      _inContentBlock = false;
    } else {
      expectStatementSeparator();
    }

    return new IncludeRule(name, arguments, scanner.spanFrom(start),
        children: children);
  }

  /// Consumes a `@media` rule.
  ///
  /// [start] should point before the `@`.
  MediaRule _mediaRule(LineScannerState start) {
    var query = _mediaQueryList();
    var children = this.children(_statement);
    return new MediaRule(query, children, scanner.spanFrom(start));
  }

  /// Consumes a mixin declaration.
  ///
  /// [start] should point before the `@`.
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
    } else if (_inControlDirective) {
      throw new StringScannerException(
          "Mixins may not be declared in control directives.",
          scanner.spanFrom(start),
          scanner.string);
    }

    whitespace();
    _inMixin = true;
    _mixinHasContent = false;
    var children = this.children(_statement);
    var hadContent = _mixinHasContent;
    _inMixin = false;
    _mixinHasContent = null;

    return new MixinRule(name, arguments, children, scanner.spanFrom(start),
        hasContent: hadContent);
  }

  /// Consumes a `@moz-document` rule.
  ///
  /// Gecko's `@-moz-document` diverges from [the specificiation][] allows the
  /// `url-prefix` and `domain` functions to omit quotation marks, contrary to
  /// the standard.
  ///
  /// [the specificiation]: http://www.w3.org/TR/css3-conditional/
  AtRule _mozDocumentRule(LineScannerState start) {
    var valueStart = scanner.state;
    var buffer = new InterpolationBuffer();
    while (true) {
      if (scanner.peekChar() == $hash) {
        buffer.add(singleInterpolation());
      } else {
        var identifierStart = scanner.state;
        var identifier = this.identifier();
        switch (identifier) {
          case "url":
          case "url-prefix":
          case "domain":
            buffer.addInterpolation(
                _urlContents(identifierStart, name: identifier));
            break;

          case "regexp":
            buffer.write("regexp(");
            scanner.expectChar($lparen);
            buffer.addInterpolation(interpolatedString().asInterpolation());
            scanner.expectChar($rparen);
            buffer.writeCharCode($rparen);
            break;

          default:
            scanner.error("Invalid function name.",
                position: identifierStart.position, length: identifier.length);
        }
      }

      whitespace();
      if (!scanner.scanChar($comma)) break;

      buffer.writeCharCode($comma);
      buffer.write(rawText(whitespace));
    }

    var value = buffer.interpolation(scanner.spanFrom(valueStart));
    var children = this.children(_statement);
    return new AtRule("-moz-document", scanner.spanFrom(start),
        value: value, children: children);
  }

  /// Consumes a `@return` rule.
  ///
  /// [start] should point before the `@`.
  ReturnRule _returnRule(LineScannerState start) {
    var expression = _expression();
    expectStatementSeparator("@return rule");
    return new ReturnRule(expression, scanner.spanFrom(start));
  }

  /// Consumes a `@supports` rule.
  ///
  /// [start] should point before the `@`.
  SupportsRule _supportsRule(LineScannerState start) {
    var condition = _supportsCondition();
    whitespace();
    return new SupportsRule(
        condition, children(_statement), scanner.spanFrom(start));
  }

  /// Consumes a `@warn` rule.
  ///
  /// [start] should point before the `@`.
  WarnRule _warnRule(LineScannerState start) {
    var expression = _expression();
    expectStatementSeparator("@warn rule");
    return new WarnRule(expression, scanner.spanFrom(start));
  }

  /// Consumes a `@while` rule.
  ///
  /// [start] should point before the `@`. [child] is called to consume any
  /// children that are specifically allowed in the caller's context.
  WhileRule _whileRule(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var expression = _expression();
    var children = this.children(child);
    _inControlDirective = wasInControlDirective;
    return new WhileRule(expression, children, scanner.spanFrom(start));
  }

  /// Consumes an at-rule that's not explicitly supported by Sass.
  ///
  /// [start] should point before the `@`. [name] is the name of the at-rule.
  AtRule _unknownAtRule(LineScannerState start, String name) {
    Interpolation value;
    var next = scanner.peekChar();
    if (next != $exclamation && !atEndOfStatement()) value = _almostAnyValue();

    var children = lookingAtChildren() ? this.children(_statement) : null;
    if (children == null) expectStatementSeparator();

    return new AtRule(name, scanner.spanFrom(start),
        value: value, children: children);
  }

  /// Throws a [StringScannerException] indicating that the at-rule starting at
  /// [start] is not allowed in the current context.
  ///
  /// This declares a return type of [Statement] so that it can be returned
  /// within case statements.
  Statement _disallowedAtRule(LineScannerState start) {
    _almostAnyValue();
    scanner.error("This at-rule is not allowed here.",
        position: start.position,
        length: scanner.state.position - start.position);
    return null;
  }

  /// Consumes an argument declaration.
  ArgumentDeclaration _argumentDeclaration() {
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();
    var arguments = <Argument>[];
    var named = normalizedSet();
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
        whitespace();
        restArgument = name;
        break;
      }

      arguments.add(new Argument(name,
          span: scanner.spanFrom(variableStart), defaultValue: defaultValue));
      if (!named.add(name)) {
        scanner.error("Duplicate argument.",
            position: arguments.last.span.start.offset,
            length: arguments.last.span.length);
      }

      if (!scanner.scanChar($comma)) break;
      whitespace();
    }
    scanner.expectChar($rparen);
    return new ArgumentDeclaration(arguments,
        restArgument: restArgument, span: scanner.spanFrom(start));
  }

  // ## Expressions

  /// Consumes an argument invocation.
  ///
  /// If [mixin] is `true`, this is parsed as a mixin invocation. Mixin
  /// invocations don't allow the Microsoft-style `=` operator at the top level,
  /// but function invocations do.
  ArgumentInvocation _argumentInvocation({bool mixin: false}) {
    var wasInParentheses = _inParentheses;
    _inParentheses = true;
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();

    var positional = <Expression>[];
    var named = normalizedMap/*<Expression>*/();
    Expression rest;
    Expression keywordRest;
    while (_lookingAtExpression()) {
      var expression = _expressionUntilComma(singleEquals: !mixin);
      whitespace();

      if (expression is VariableExpression && scanner.scanChar($colon)) {
        whitespace();
        if (named.containsKey(expression.name)) {
          scanner.error("Duplicate argument.",
              position: expression.span.start.offset,
              length: expression.span.length);
        }
        named[expression.name] = _expressionUntilComma(singleEquals: !mixin);
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

    _inParentheses = wasInParentheses;
    return new ArgumentInvocation(positional, named, scanner.spanFrom(start),
        rest: rest, keywordRest: keywordRest);
  }

  /// Consumes an expression.
  ///
  /// If [bracketList] is true, this parses this expression as the contents of a
  /// bracketed list.
  ///
  /// If [singleEquals] is true, this will allow the Microsoft-style `=`
  /// operator at the top level.
  ///
  /// If [until] is passed, it's called each time the expression could end and
  /// still be a valid expression. When it returns `true`, this returns the
  /// expression.
  Expression _expression(
      {bool bracketList: false, bool singleEquals: false, bool until()}) {
    if (until != null && until()) scanner.error("Expected expression.");

    LineScannerState beforeBracket;
    if (bracketList) {
      beforeBracket = scanner.state;
      scanner.expectChar($lbracket);
      whitespace();

      if (scanner.scanChar($rbracket)) {
        return new ListExpression([], ListSeparator.undecided,
            brackets: true, span: scanner.spanFrom(beforeBracket));
      }
    }

    var start = scanner.state;
    var wasInParentheses = _inParentheses;

    List<Expression> commaExpressions;

    Expression singleEqualsOperand;

    List<Expression> spaceExpressions;

    // Operators whose right-hand operands are not fully parsed yet, in order of
    // appearance in the document. Because a low-precedence operator will cause
    // parsing to finish for all preceding higher-precedence operators, this is
    // naturally ordered from lowest to highest precedence.
    List<BinaryOperator> operators;

    // The left-hand sides of [operators]. `operands[n]` is the left-hand side
    // of `operators[n]`.
    List<Expression> operands;

    /// Whether the single expression parsed so far may be interpreted as
    /// slash-separated numbers.
    var allowSlash = lookingAtNumber();

    /// The leftmost expression that's been fully-parsed. Never `null`.
    var singleExpression = _singleExpression();

    // Resets the scanner state to the state it was at at the beginning of the
    // expression, except for [_inParentheses].
    resetState() {
      commaExpressions = null;
      spaceExpressions = null;
      operators = null;
      operands = null;
      scanner.state = start;
      allowSlash = lookingAtNumber();
      singleExpression = _singleExpression();
    }

    resolveOneOperation() {
      var operator = operators.removeLast();
      if (operator != BinaryOperator.dividedBy) allowSlash = false;
      if (allowSlash && !_inParentheses) {
        singleExpression = new BinaryOperationExpression.slash(
            operands.removeLast(), singleExpression);
      } else {
        singleExpression = new BinaryOperationExpression(
            operator, operands.removeLast(), singleExpression);
      }
    }

    resolveOperations() {
      if (operators == null) return;
      while (!operators.isEmpty) {
        resolveOneOperation();
      }
    }

    addSingleExpression(Expression expression, {bool number: false}) {
      if (singleExpression != null) {
        // If we discover we're parsing a list whose first element is a division
        // operation, and we're in parentheses, reparse outside of a paren
        // context. This ensures that `(1/2 1)` doesn't perform division on its
        // first element.
        if (_inParentheses) {
          _inParentheses = false;
          if (allowSlash) {
            resetState();
            return;
          }
        }

        spaceExpressions ??= [];
        resolveOperations();
        spaceExpressions.add(singleExpression);
        allowSlash = number;
      } else if (!number) {
        allowSlash = false;
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
      whitespace();
      allowSlash = allowSlash && lookingAtNumber();
      singleExpression = _singleExpression();
      allowSlash = allowSlash && singleExpression is NumberExpression;
    }

    resolveSpaceExpressions() {
      resolveOperations();

      if (spaceExpressions != null) {
        spaceExpressions.add(singleExpression);
        singleExpression =
            new ListExpression(spaceExpressions, ListSeparator.space);
        spaceExpressions = null;
      }

      if (singleEqualsOperand != null) {
        singleExpression = new BinaryOperationExpression(
            BinaryOperator.singleEquals, singleEqualsOperand, singleExpression);
        singleEqualsOperand = null;
      }
    }

    loop:
    while (true) {
      whitespace();
      if (until != null && until()) break;

      var first = scanner.peekChar();
      switch (first) {
        case $lparen:
          // Parenthesized numbers can't be slash-separated.
          addSingleExpression(_parentheses());
          break;

        case $lbracket:
          addSingleExpression(_expression(bracketList: true));
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
          if (singleEquals && scanner.peekChar() != $equal) {
            resolveSpaceExpressions();
            singleEqualsOperand = singleExpression;
            singleExpression = null;
          } else {
            scanner.expectChar($equal);
            addOperator(BinaryOperator.equals);
          }
          break;

        case $exclamation:
          var next = scanner.peekChar(1);
          if (next == $equal) {
            scanner.readChar();
            scanner.readChar();
            addOperator(BinaryOperator.notEquals);
          } else if (next == null ||
              equalsLetterIgnoreCase($i, next) ||
              isWhitespace(next)) {
            addSingleExpression(_importantExpression());
          } else {
            break loop;
          }
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
          if ((isDigit(next) || next == $dot) &&
              // Make sure `1-2` parses as `1 - 2`, not `1 (-2)`.
              (singleExpression == null ||
                  isWhitespace(scanner.peekChar(-1)))) {
            addSingleExpression(_number(), number: true);
          } else if (lookingAtIdentifier()) {
            addSingleExpression(_identifierLike());
          } else {
            scanner.readChar();
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
          addSingleExpression(_number(), number: true);
          break;

        case $dot:
          if (scanner.peekChar(1) == $dot) break loop;
          addSingleExpression(_number(), number: true);
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
            addOperator(BinaryOperator.or);
          } else {
            addSingleExpression(_identifierLike());
          }
          break;

        case $u:
        case $U:
          if (scanner.peekChar(1) == $plus) {
            addSingleExpression(_unicodeRange());
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
          // If we discover we're parsing a list whose first element is a
          // division operation, and we're in parentheses, reparse outside of a
          // paren context. This ensures that `(1/2, 1)` doesn't perform division
          // on its first element.
          if (_inParentheses) {
            _inParentheses = false;
            if (allowSlash) {
              resetState();
              break;
            }
          }

          commaExpressions ??= [];
          if (singleExpression == null) scanner.error("Expected expression.");

          resolveSpaceExpressions();
          commaExpressions.add(singleExpression);
          scanner.readChar();
          allowSlash = true;
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

    if (bracketList) scanner.expectChar($rbracket);
    if (commaExpressions != null) {
      resolveSpaceExpressions();
      _inParentheses = wasInParentheses;
      if (singleExpression != null) commaExpressions.add(singleExpression);
      return new ListExpression(commaExpressions, ListSeparator.comma,
          brackets: bracketList,
          span: bracketList ? scanner.spanFrom(beforeBracket) : null);
    } else if (bracketList &&
        spaceExpressions != null &&
        singleEqualsOperand == null) {
      resolveOperations();
      return new ListExpression(
          spaceExpressions..add(singleExpression), ListSeparator.space,
          brackets: true, span: scanner.spanFrom(beforeBracket));
    } else {
      resolveSpaceExpressions();
      if (bracketList) {
        singleExpression = new ListExpression(
            [singleExpression], ListSeparator.undecided,
            brackets: true, span: scanner.spanFrom(beforeBracket));
      }
      return singleExpression;
    }
  }

  /// Consumes an expression until it reaches a top-level comma.
  ///
  /// If [singleEquals] is true, this will allow the Microsoft-style `=`
  /// operator at the top level.
  Expression _expressionUntilComma({bool singleEquals: false}) => _expression(
      singleEquals: singleEquals, until: () => scanner.peekChar() == $comma);

  /// Consumes an expression that doesn't contain any top-level whitespace.
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
        return _expression(bracketList: true);
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

      case $exclamation:
        return _importantExpression();

      case $u:
      case $U:
        if (scanner.peekChar(1) == $plus) {
          return _unicodeRange();
        } else {
          return _identifierLike();
        }
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

  /// Consumes a parenthesized expression.
  Expression _parentheses() {
    var wasInParentheses = _inParentheses;
    _inParentheses = true;
    try {
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
    } finally {
      _inParentheses = wasInParentheses;
    }
  }

  /// Consumes a map expression.
  ///
  /// This expects to be called after the first colon in the map, with [first]
  /// as the expression before the colon and [start] the point before the
  /// opening parenthesis.
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

  /// Consumes an expression that starts with a `#`.
  Expression _hashExpression() {
    assert(scanner.peekChar() == $hash);
    if (scanner.peekChar(1) == $lbrace) return _identifierLike();

    var start = scanner.state;
    scanner.expectChar($hash);

    var first = scanner.peekChar();
    if (first != null && isDigit(first)) {
      var color = _hexColorContents();
      var span = scanner.spanFrom(start);
      setOriginalSpan(color, span);
      return new ColorExpression(color, span);
    }

    var afterHash = scanner.state;
    var identifier = _interpolatedIdentifier();
    if (_isHexColor(identifier)) {
      scanner.state = afterHash;
      var color = _hexColorContents();
      var span = scanner.spanFrom(start);
      setOriginalSpan(color, span);
      return new ColorExpression(color, span);
    }

    var buffer = new InterpolationBuffer();
    buffer.writeCharCode($hash);
    buffer.addInterpolation(identifier);
    return new StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  /// Consumes the contents of a hex color, after the `#`.
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

  /// Returns whether [interpolation] is a plain string that can be parsed as a
  /// hex color.
  bool _isHexColor(Interpolation interpolation) {
    var plain = interpolation.asPlain;
    if (plain == null) return false;
    if (plain.length != 3 && plain.length != 6) return false;
    return plain.codeUnits.every(isHex);
  }

  // Consumes a single hexadecimal digit.
  int _hexDigit() {
    var char = scanner.peekChar();
    if (char == null || !isHex(char)) scanner.error("Expected hex digit.");
    return asHex(scanner.readChar());
  }

  /// Consumes an expression that starts with a `+`.
  Expression _plusExpression() {
    assert(scanner.peekChar() == $plus);
    var next = scanner.peekChar(1);
    return isDigit(next) || next == $dot ? _number() : _unaryOperation();
  }

  /// Consumes an expression that starts with a `-`.
  Expression _minusExpression() {
    assert(scanner.peekChar() == $minus);
    var next = scanner.peekChar(1);
    if (isDigit(next) || next == $dot) return _number();
    if (_lookingAtInterpolatedIdentifier()) return _identifierLike();
    return _unaryOperation();
  }

  /// Consumes an `!important` expression.
  Expression _importantExpression() {
    assert(scanner.peekChar() == $exclamation);

    var start = scanner.state;
    scanner.readChar();
    whitespace();
    expectIdentifier("important", ignoreCase: true);
    return new StringExpression.plain("!important", scanner.spanFrom(start));
  }

  /// Consumes a unary operation expression.
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

  /// Returns the unsary operator corresponding to [character], or `null` if
  /// the character is not a unary operator.
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

  /// Consumes a number expression.
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
      number += asDecimal(scanner.readChar());
    }

    if (scanner.peekChar() == $dot) {
      if (!isDigit(scanner.peekChar(1))) {
        if (first == $dot) {
          scanner.error("Expected digit.", position: scanner.position + 1);
        }
      } else {
        scanner.readChar();
        var decimal = 0.1;
        while (isDigit(scanner.peekChar())) {
          number += asDecimal(scanner.readChar()) * decimal;
          decimal /= 10;
        }
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
    } else if (lookingAtIdentifier() &&
        // Disallow units beginning with `--`.
        (scanner.peekChar() != $dash || scanner.peekChar(1) != $dash)) {
      unit = identifier(unit: true);
    }

    return new NumberExpression(sign * number, scanner.spanFrom(start),
        unit: unit);
  }

  /// Consumes a unicode range expression.
  StringExpression _unicodeRange() {
    var start = scanner.state;
    expectCharIgnoreCase($u);
    scanner.expectChar($plus);

    var i = 0;
    for (; i < 6; i++) {
      if (!scanCharIf((char) => char != null && isHex(char))) break;
    }

    if (scanner.scanChar($question)) {
      i++;
      for (; i < 6; i++) {
        if (!scanner.scanChar($question)) break;
      }
      return new StringExpression.plain(
          scanner.substring(start.position), scanner.spanFrom(start));
    }
    if (i == 0) scanner.error('Expected hex digit or "?".');

    if (scanner.scanChar($minus)) {
      var j = 0;
      for (; j < 6; j++) {
        if (!scanCharIf((char) => char != null && isHex(char))) break;
      }
      if (j == 0) scanner.error("Expected hex digit.");
    }

    if (_lookingAtInterpolatedIdentifierBody()) {
      scanner.error("Expected end of identifier.");
    }

    return new StringExpression.plain(
        scanner.substring(start.position), scanner.spanFrom(start));
  }

  /// Consumes a variable expression.
  VariableExpression _variable() {
    var start = scanner.state;
    return new VariableExpression(variableName(), scanner.spanFrom(start));
  }

  /// Consumes a selector expression.
  SelectorExpression _selector() {
    var start = scanner.state;
    scanner.expectChar($ampersand);
    return new SelectorExpression(scanner.spanFrom(start));
  }

  /// Consumes a quoted string expression.
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
        var second = scanner.peekChar(1);
        if (isNewline(second)) {
          scanner.readChar();
          scanner.readChar();
          if (second == $cr) scanner.scanChar($lf);
        } else {
          buffer.writeCharCode(escapeCharacter());
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

  /// Consumes an expression that starts like an identifier.
  Expression _identifierLike() {
    var start = scanner.state;
    var identifier = _interpolatedIdentifier();
    var plain = identifier.asPlain;
    if (plain != null) {
      if (plain == "if") {
        var invocation = _argumentInvocation();
        return new IfExpression(
            invocation, spanForList([identifier, invocation]));
      } else if (plain == "not") {
        whitespace();
        return new UnaryOperationExpression(
            UnaryOperator.not, _singleExpression(), identifier.span);
      }

      var lower = plain.toLowerCase();
      if (scanner.peekChar() != $lparen) {
        switch (plain) {
          case "false":
            return new BooleanExpression(false, identifier.span);
          case "null":
            return new NullExpression(identifier.span);
          case "true":
            return new BooleanExpression(true, identifier.span);
        }

        var color = colorsByName[lower];
        if (color != null) {
          // TODO(nweiz): Avoid copying the color in compressed mode.
          color = new SassColor.rgb(
              color.red, color.green, color.blue, color.alpha);
          setOriginalSpan(color, identifier.span);
          return new ColorExpression(color, identifier.span);
        }
      }

      var specialFunction = _trySpecialFunction(lower, start);
      if (specialFunction != null) return specialFunction;
    }

    return scanner.peekChar() == $lparen
        ? new FunctionExpression(identifier, _argumentInvocation())
        : new StringExpression(identifier);
  }

  /// If [name] is the name of a function with special syntax, consumes it.
  ///
  /// Otherwise, returns `null`. [start] is the location before the beginning of
  /// [name].
  Expression _trySpecialFunction(String name, LineScannerState start) {
    var normalized = unvendor(name);

    InterpolationBuffer buffer;
    switch (normalized) {
      case "calc":
      case "element":
      case "expression":
        if (!scanner.scanChar($lparen)) return null;
        buffer = new InterpolationBuffer()
          ..write(name)
          ..writeCharCode($lparen);
        break;

      case "progid":
        if (!scanner.scanChar($colon)) return null;
        buffer = new InterpolationBuffer()
          ..write(name)
          ..writeCharCode($colon);
        var next = scanner.peekChar();
        while (next != null && (isAlphabetic(next) || next == $dot)) {
          buffer.writeCharCode(scanner.readChar());
          next = scanner.peekChar();
        }
        scanner.expectChar($lparen);
        buffer.writeCharCode($lparen);
        break;

      case "url":
        var contents = _tryUrlContents(start);
        if (contents != null) return new StringExpression(contents);
        return new FunctionExpression(
            new Interpolation(["url"], scanner.spanFrom(start)),
            _argumentInvocation());

      default:
        return null;
    }

    buffer.addInterpolation(_interpolatedDeclarationValue().text);
    scanner.expectChar($rparen);
    buffer.writeCharCode($rparen);

    return new StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  /// Consumes the contents of a `url()` token (after the name).
  ///
  /// [start] is the position before the beginning of the name. [name] is the
  /// function's name; it defaults to `"url"`.
  Interpolation _urlContents(LineScannerState start, {String name}) {
    // NOTE: this logic is largely duplicated in [_tryUrlContents] and
    // Parser.tryUrl. Most changes here should be mirrored there.

    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespaceWithoutComments();

    // Match Ruby Sass's behavior: parse a raw URL() if possible, and if not
    // backtrack and re-parse as a function expression.
    var buffer = new InterpolationBuffer()..write("${name ?? 'url'}(");
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $percent ||
          next == $ampersand ||
          (next >= $asterisk && next <= $tilde) ||
          next >= 0x0080) {
        buffer.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        buffer.write(escape());
      } else if (next == $hash) {
        if (scanner.peekChar(1) == $lbrace) {
          buffer.add(singleInterpolation());
        } else {
          buffer.writeCharCode(scanner.readChar());
        }
      } else if (isWhitespace(next)) {
        whitespaceWithoutComments();
        scanner.expectChar($rparen);
        buffer.writeCharCode($rparen);
        break;
      } else if (next == $rparen) {
        buffer.writeCharCode(scanner.readChar());
        break;
      } else {
        scanner.expectChar($rparen);
      }
    }

    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Like [_urlContents], but returns `null` if the URL fails to parse.
  Interpolation _tryUrlContents(LineScannerState start) {
    // NOTE: this logic is largely duplicated in [_urlContents] and
    // Parser.tryUrl. Most changes here should be mirrored there.

    var start = scanner.state;
    if (!scanner.scanChar($lparen)) return null;
    whitespaceWithoutComments();

    // Match Ruby Sass's behavior: parse a raw URL() if possible, and if not
    // backtrack and re-parse as a function expression.
    var buffer = new InterpolationBuffer()..write("url(");
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $percent ||
          next == $ampersand ||
          (next >= $asterisk && next <= $tilde) ||
          next >= 0x0080) {
        buffer.writeCharCode(scanner.readChar());
      } else if (next == $backslash) {
        buffer.write(escape());
      } else if (next == $hash) {
        if (scanner.peekChar(1) == $lbrace) {
          buffer.add(singleInterpolation());
        } else {
          buffer.writeCharCode(scanner.readChar());
        }
      } else if (isWhitespace(next)) {
        whitespaceWithoutComments();
        if (scanner.peekChar() != $rparen) break;
      } else if (next == $rparen) {
        buffer.writeCharCode(scanner.readChar());
        return buffer.interpolation(scanner.spanFrom(start));
      } else {
        break;
      }
    }

    scanner.state = start;
    return null;
  }

  /// Consumes a [url] token that's allowed to contain SassScript.
  Expression _dynamicUrl() {
    var start = scanner.state;
    expectIdentifier("url", ignoreCase: true);
    var contents = _tryUrlContents(start);
    if (contents != null) return new StringExpression(contents);

    return new FunctionExpression(
        new Interpolation(["url"], scanner.spanFrom(start)),
        _argumentInvocation());
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
          if (scanComment()) {
            buffer.write(scanner.substring(commentStart));
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          break;

        case $hash:
          if (scanner.peekChar(1) == $lbrace) {
            // Add a full interpolated identifier to handle cases like
            // "#{...}--1", since "--1" isn't a valid identifier on its own.
            buffer.addInterpolation(_interpolatedIdentifier());
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

        case $u:
        case $U:
          var beforeUrl = scanner.state;
          if (!scanIdentifier("url", ignoreCase: true)) {
            buffer.writeCharCode(scanner.readChar());
            break;
          }

          var contents = _tryUrlContents(beforeUrl);
          if (contents == null) {
            scanner.state = beforeUrl;
            buffer.writeCharCode(scanner.readChar());
          } else {
            buffer.addInterpolation(contents);
          }
          break;

        default:
          if (next == null) break loop;

          if (lookingAtIdentifier()) {
            buffer.write(identifier());
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          break;
      }
    }

    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes tokens until it reaches a top-level `":"`, `"!"`, `")"`, `"]"`,
  /// or `"}"` and returns their contents as a string.
  ///
  /// Unlike [declarationValue], this allows interpolation.
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
          buffer.write(escape());
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
            // Add a full interpolated identifier to handle cases like
            // "#{...}--1", since "--1" isn't a valid identifier on its own.
            buffer.addInterpolation(_interpolatedIdentifier());
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          wroteNewline = false;
          break;

        case $space:
        case $tab:
          if (wroteNewline || !isWhitespace(scanner.peekChar(1))) {
            buffer.writeCharCode(scanner.readChar());
          } else {
            scanner.readChar();
          }
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
          if (brackets.isEmpty) break loop;
          buffer.writeCharCode(scanner.readChar());
          break;

        case $u:
        case $U:
          var beforeUrl = scanner.state;
          if (!scanIdentifier("url", ignoreCase: true)) {
            buffer.writeCharCode(scanner.readChar());
            wroteNewline = false;
            break;
          }

          var contents = _tryUrlContents(beforeUrl);
          if (contents == null) {
            scanner.state = beforeUrl;
            buffer.writeCharCode(scanner.readChar());
          } else {
            buffer.addInterpolation(contents);
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
    return new StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  /// Consumes an identifier that may contain interpolation.
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
      buffer.write(escape());
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
        buffer.write(escape());
      } else if (next == $hash && scanner.peekChar(1) == $lbrace) {
        buffer.add(singleInterpolation());
      } else {
        break;
      }
    }

    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes interpolation.
  Expression singleInterpolation() {
    scanner.expect('#{');
    whitespace();
    var expression = _expression();
    scanner.expectChar($rbrace);
    return expression;
  }

  /// Consumes a query expression of the form `(foo: bar)`.
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

  /// Consumes a list of media queries.
  Interpolation _mediaQueryList() {
    var start = scanner.state;
    var buffer = new InterpolationBuffer();
    while (true) {
      whitespace();
      _mediaQuery(buffer);
      if (!scanner.scanChar($comma)) break;
      buffer.writeCharCode($comma);
      buffer.writeCharCode($space);
    }
    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes a single media query.
  void _mediaQuery(InterpolationBuffer buffer) {
    // This is somewhat duplicated in MediaQueryParser._mediaQuery.
    if (scanner.peekChar() != $lparen) {
      buffer.addInterpolation(_interpolatedIdentifier());
      whitespace();

      if (!_lookingAtInterpolatedIdentifier()) {
        // For example, "@media screen {".
        return;
      }

      buffer.writeCharCode($space);
      var identifier = _interpolatedIdentifier();
      whitespace();

      if (equalsIgnoreCase(identifier.asPlain, "and")) {
        // For example, "@media screen and ..."
        buffer.write(" and ");
      } else {
        buffer.addInterpolation(identifier);
        if (scanIdentifier("and", ignoreCase: true)) {
          // For example, "@media only screen and ..."
          whitespace();
          buffer.write(" and ");
        } else {
          // For example, "@media only screen {"
          return;
        }
      }
    }

    // We've consumed either `IDENTIFIER "and"` or
    // `IDENTIFIER IDENTIFIER "and"`.

    while (true) {
      whitespace();
      buffer.addInterpolation(_queryExpression());
      whitespace();
      if (!scanIdentifier("and", ignoreCase: true)) break;
      buffer.write(" and ");
    }
  }

  // ## Supports Conditions

  /// Consumes a `@supports` condition.
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

  /// Consumes a parenthesized supports condition, or an interpolation.
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

  /// Tries to consume a negated supports condition.
  ///
  /// Returns `null` if it fails.
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

  /// Returns whether the scanner is immediately before an identifier that may
  /// contain interpolation.
  ///
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
    if (second == null) return false;
    if (isNameStart(second) || second == $backslash) return true;

    if (second == $hash) return scanner.peekChar(2) == $lbrace;
    if (second != $dash) return false;

    var third = scanner.peekChar(2);
    if (third == null) return false;
    if (third == $hash) return scanner.peekChar(3) == $lbrace;
    return isNameStart(third);
  }

  /// Returns whether the scanner is immediately before a sequence of characters
  /// that could be part of an CSS identifier body.
  ///
  /// The identifier body may include interpolation.
  bool _lookingAtInterpolatedIdentifierBody() {
    var first = scanner.peekChar();
    if (first == null) return false;
    if (isName(first) || first == $backslash) return true;
    return first == $hash && scanner.peekChar(1) == $lbrace;
  }

  /// Returns whether the scanner is immediately before a SassScript expression.
  bool _lookingAtExpression() {
    var character = scanner.peekChar();
    if (character == null) return false;
    if (character == $dot) return scanner.peekChar(1) != $dot;
    if (character == $exclamation) {
      var next = scanner.peekChar(1);
      return next == null ||
          equalsLetterIgnoreCase($i, next) ||
          isWhitespace(next);
    }

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

  // ## Utilities

  // ## Abstract Methods

  /// Whether this is parsing the indented syntax.
  bool get indented;

  /// The indentation level at the current scanner position.
  ///
  /// This value isn't used directly by [StylesheetParser]; it's just passed to
  /// [scanElse].
  int get currentIndentation;

  /// Asserts that the scanner is positioned before a statement separator, or at
  /// the end of a list of statements.
  ///
  /// If the [name] of the parent rule is passed, it's used for error reporting.
  ///
  /// This consumes whitespace, but nothing else, including comments.
  void expectStatementSeparator([String name]);

  /// Whether the scanner is positioned at the end of a statement.
  bool atEndOfStatement();

  /// Whether the scanner is positioned before a block of children that can be
  /// parsed with [children].
  bool lookingAtChildren();

  /// Tries to scan an `@else` rule after an `@if` block, and returns whether
  /// that succeeded.
  ///
  /// This should just scan the rule name, not anything afterwards.
  /// [ifIndentation] is the result of [currentIndentation] from before the
  /// corresponding `@if` was parsed.
  bool scanElse(int ifIndentation);

  /// Consumes a block of child statements.
  List<Statement> children(Statement child());

  /// Consumes top-level statements.
  ///
  /// The [statement] callback may return `null`, indicating that a statement
  /// was consumed that shouldn't be added to the AST.
  List<Statement> statements(Statement statement());
}
