// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';
import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../color_names.dart';
import '../exception.dart';
import '../interpolation_buffer.dart';
import '../logger.dart';
import '../util/character.dart';
import '../utils.dart';
import '../util/nullable.dart';
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
  /// Whether we've consumed a rule other than `@charset`, `@forward`, or
  /// `@use`.
  var _isUseAllowed = true;

  /// Whether the parser is currently parsing the contents of a mixin
  /// declaration.
  var _inMixin = false;

  /// Whether the parser is currently parsing a content block passed to a mixin.
  var _inContentBlock = false;

  /// Whether the parser is currently parsing a control directive such as `@if`
  /// or `@each`.
  var _inControlDirective = false;

  /// Whether the parser is currently parsing an unknown rule.
  var _inUnknownAtRule = false;

  /// Whether the parser is currently parsing a style rule.
  var _inStyleRule = false;

  /// Whether the parser is currently within a parenthesized expression.
  var _inParentheses = false;

  /// A map from all variable names that are assigned with `!global` in the
  /// current stylesheet to the nodes where they're defined.
  ///
  /// These are collected at parse time because they affect the variables
  /// exposed by the module generated for this stylesheet, *even if they aren't
  /// evaluated*. This allows us to ensure that the stylesheet always exposes
  /// the same set of variable names no matter how it's evaluated.
  final _globalVariables = <String, VariableDeclaration>{};

  /// The silent comment this parser encountered previously.
  @protected
  SilentComment? lastSilentComment;

  StylesheetParser(String contents, {Object? url, Logger? logger})
      : super(contents, url: url, logger: logger);

  // ## Statements

  Stylesheet parse() {
    return wrapSpanFormatException(() {
      var start = scanner.state;
      // Allow a byte-order mark at the beginning of the document.
      scanner.scanChar(0xFEFF);
      var statements = this.statements(() {
        // Handle this specially so that [atRule] always returns a non-nullable
        // Statement.
        if (scanner.scan('@charset')) {
          whitespace();
          string();
          return null;
        }

        return _statement(root: true);
      });
      scanner.expectDone();

      /// Ensure that all global variable assignments produce a variable in this
      /// stylesheet, even if they aren't evaluated. See sass/language#50.
      statements.addAll(_globalVariables.values.map((declaration) =>
          VariableDeclaration(declaration.name,
              NullExpression(declaration.expression.span), declaration.span,
              guarded: true)));

      return Stylesheet.internal(statements, scanner.spanFrom(start),
          plainCss: plainCss);
    });
  }

  ArgumentDeclaration parseArgumentDeclaration() => _parseSingleProduction(() {
        scanner.expectChar($at, name: "@-rule");
        identifier();
        whitespace();
        identifier();
        var arguments = _argumentDeclaration();
        whitespace();
        scanner.expectChar($lbrace);
        return arguments;
      });

  Expression parseExpression() => _parseSingleProduction(_expression);

  VariableDeclaration parseVariableDeclaration() =>
      _parseSingleProduction(() => lookingAtIdentifier()
          ? _variableDeclarationWithNamespace()
          : variableDeclarationWithoutNamespace());

  UseRule parseUseRule() => _parseSingleProduction(() {
        var start = scanner.state;
        scanner.expectChar($at, name: "@-rule");
        expectIdentifier("use");
        whitespace();
        return _useRule(start);
      });

  /// Parses and returns [production] as the entire contents of [scanner].
  T _parseSingleProduction<T>(T production()) {
    return wrapSpanFormatException(() {
      var result = production();
      scanner.expectDone();
      return result;
    });
  }

  /// Parses a function signature of the format allowed by Node Sass's functions
  /// option and returns its name and declaration.
  ///
  /// If [requireParens] is `false`, this allows parentheses to be omitted.
  Tuple2<String, ArgumentDeclaration> parseSignature(
      {bool requireParens = true}) {
    return wrapSpanFormatException(() {
      var name = identifier();
      whitespace();
      var arguments = requireParens || scanner.peekChar() == $lparen
          ? _argumentDeclaration()
          : ArgumentDeclaration.empty(scanner.emptySpan);
      scanner.expectDone();
      return Tuple2(name, arguments);
    });
  }

  /// Consumes a statement that's allowed at the top level of the stylesheet or
  /// within nested style and at rules.
  ///
  /// If [root] is `true`, this parses at-rules that are allowed only at the
  /// root of the stylesheet.
  Statement _statement({bool root = false}) {
    switch (scanner.peekChar()) {
      case $at:
        return atRule(() => _statement(), root: root);

      case $plus:
        if (!indented || !lookingAtIdentifier(1)) return _styleRule();
        _isUseAllowed = false;
        var start = scanner.state;
        scanner.readChar();
        return _includeRule(start);

      case $equal:
        if (!indented) return _styleRule();
        _isUseAllowed = false;
        var start = scanner.state;
        scanner.readChar();
        whitespace();
        return _mixinRule(start);

      case $rbrace:
        scanner.error('unmatched "}".', length: 1);

      default:
        return _inStyleRule || _inUnknownAtRule || _inMixin || _inContentBlock
            ? _declarationOrStyleRule()
            : _variableDeclarationOrStyleRule();
    }
  }

  /// Consumes a namespaced variable declaration.
  VariableDeclaration _variableDeclarationWithNamespace() {
    var start = scanner.state;
    var namespace = identifier();
    scanner.expectChar($dot);
    return variableDeclarationWithoutNamespace(namespace, start);
  }

  /// Consumes a variable declaration.
  ///
  /// This never *consumes* a namespace, but if [namespace] is passed it will be
  /// used for the declaration.
  @protected
  VariableDeclaration variableDeclarationWithoutNamespace(
      [String? namespace, LineScannerState? start_]) {
    var precedingComment = lastSilentComment;
    lastSilentComment = null;
    var start = start_ ?? scanner.state; // dart-lang/sdk#45348

    var name = variableName();
    if (namespace != null) _assertPublic(name, () => scanner.spanFrom(start));

    if (plainCss) {
      error("Sass variables aren't allowed in plain CSS.",
          scanner.spanFrom(start));
    }

    whitespace();
    scanner.expectChar($colon);
    whitespace();

    var value = _expression();

    var guarded = false;
    var global = false;
    var flagStart = scanner.state;
    while (scanner.scanChar($exclamation)) {
      var flag = identifier();
      if (flag == 'default') {
        guarded = true;
      } else if (flag == 'global') {
        if (namespace != null) {
          error("!global isn't allowed for variables in other modules.",
              scanner.spanFrom(flagStart));
        }

        global = true;
      } else {
        error("Invalid flag name.", scanner.spanFrom(flagStart));
      }

      whitespace();
      flagStart = scanner.state;
    }

    expectStatementSeparator("variable declaration");
    var declaration = VariableDeclaration(name, value, scanner.spanFrom(start),
        namespace: namespace,
        guarded: guarded,
        global: global,
        comment: precedingComment);
    if (global) _globalVariables.putIfAbsent(name, () => declaration);
    return declaration;
  }

  /// Consumes a namespaced [VariableDeclaration] or a [StyleRule].
  Statement _variableDeclarationOrStyleRule() {
    if (plainCss) return _styleRule();

    // The indented syntax allows a single backslash to distinguish a style rule
    // from old-style property syntax. We don't support old property syntax, but
    // we do support the backslash because it's easy to do.
    if (indented && scanner.scanChar($backslash)) return _styleRule();

    if (!lookingAtIdentifier()) return _styleRule();

    var start = scanner.state;
    var variableOrInterpolation = _variableDeclarationOrInterpolation();
    if (variableOrInterpolation is VariableDeclaration) {
      return variableOrInterpolation;
    } else {
      return _styleRule(
          InterpolationBuffer()
            ..addInterpolation(variableOrInterpolation as Interpolation),
          start);
    }
  }

  /// Consumes a [VariableDeclaration], a [Declaration], or a [StyleRule].
  ///
  /// When parsing the children of a style rule, property declarations,
  /// namespaced variable declarations, and nested style rules can all begin
  /// with bare identifiers. In order to know which statement type to produce,
  /// we need to disambiguate them. We use the following criteria:
  ///
  /// * If the entity starts with an identifier followed by a period and a
  ///   dollar sign, it's a variable declaration. This is the simplest case,
  ///   because `.$` is used in and only in variable declarations.
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
  /// * If the declaration value is valid but is followed by "{", backtrack and
  ///   parse it as a selector anyway. This ensures that ".foo:bar {" is always
  ///   parsed as a selector and never as a property with nested properties
  ///   beneath it.
  Statement _declarationOrStyleRule() {
    if (plainCss && _inStyleRule && !_inUnknownAtRule) {
      return _propertyOrVariableDeclaration();
    }

    // The indented syntax allows a single backslash to distinguish a style rule
    // from old-style property syntax. We don't support old property syntax, but
    // we do support the backslash because it's easy to do.
    if (indented && scanner.scanChar($backslash)) return _styleRule();

    var start = scanner.state;
    var declarationOrBuffer = _declarationOrBuffer();
    return declarationOrBuffer is Statement
        ? declarationOrBuffer
        : _styleRule(declarationOrBuffer as InterpolationBuffer, start);
  }

  /// Tries to parse a variable or property declaration, and returns the value
  /// parsed so far if it fails.
  ///
  /// This can return either an [InterpolationBuffer], indicating that it
  /// couldn't consume a declaration and that selector parsing should be
  /// attempted; or it can return a [Declaration] or a [VariableDeclaration],
  /// indicating that it successfully consumed a declaration.
  dynamic _declarationOrBuffer() {
    var start = scanner.state;
    var nameBuffer = InterpolationBuffer();

    // Allow the "*prop: val", ":prop: val", "#prop: val", and ".prop: val"
    // hacks.
    var first = scanner.peekChar();
    var startsWithPunctuation = false;
    if (first == $colon ||
        first == $asterisk ||
        first == $dot ||
        (first == $hash && scanner.peekChar(1) != $lbrace)) {
      startsWithPunctuation = true;
      nameBuffer.writeCharCode(scanner.readChar());
      nameBuffer.write(rawText(whitespace));
    }

    if (!_lookingAtInterpolatedIdentifier()) return nameBuffer;

    var variableOrInterpolation = startsWithPunctuation
        ? interpolatedIdentifier()
        : _variableDeclarationOrInterpolation();
    if (variableOrInterpolation is VariableDeclaration) {
      return variableOrInterpolation;
    } else {
      nameBuffer.addInterpolation(variableOrInterpolation as Interpolation);
    }

    _isUseAllowed = false;
    if (scanner.matches("/*")) nameBuffer.write(rawText(loudComment));

    var midBuffer = StringBuffer();
    midBuffer.write(rawText(whitespace));
    var beforeColon = scanner.state;
    if (!scanner.scanChar($colon)) {
      if (midBuffer.isNotEmpty) nameBuffer.writeCharCode($space);
      return nameBuffer;
    }
    midBuffer.writeCharCode($colon);

    // Parse custom properties as declarations no matter what.
    var name = nameBuffer.interpolation(scanner.spanFrom(start, beforeColon));
    if (name.initialPlain.startsWith('--')) {
      var value = StringExpression(_interpolatedDeclarationValue());
      expectStatementSeparator("custom property");
      return Declaration(name, value, scanner.spanFrom(start));
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
      return _withChildren(_declarationChild, start,
          (children, span) => Declaration.nested(name, children, span));
    }

    midBuffer.write(postColonWhitespace);
    var couldBeSelector =
        postColonWhitespace.isEmpty && _lookingAtInterpolatedIdentifier();

    var beforeDeclaration = scanner.state;
    Expression value;
    try {
      value = _expression();

      if (lookingAtChildren()) {
        // Properties that are ambiguous with selectors can't have additional
        // properties nested beneath them, so we force an error. This will be
        // caught below and cause the text to be reparsed as a selector.
        if (couldBeSelector) expectStatementSeparator();
      } else if (!atEndOfStatement()) {
        // Force an exception if there isn't a valid end-of-property character
        // but don't consume that character. This will also cause the text to be
        // reparsed.
        expectStatementSeparator();
      }
    } on FormatException catch (_) {
      if (!couldBeSelector) rethrow;

      // If the value would be followed by a semicolon, it's definitely supposed
      // to be a property, not a selector.
      scanner.state = beforeDeclaration;
      var additional = almostAnyValue();
      if (!indented && scanner.peekChar() == $semicolon) rethrow;

      nameBuffer.write(midBuffer);
      nameBuffer.addInterpolation(additional);
      return nameBuffer;
    }

    if (lookingAtChildren()) {
      return _withChildren(
          _declarationChild,
          start,
          (children, span) =>
              Declaration.nested(name, children, span, value: value));
    } else {
      expectStatementSeparator();
      return Declaration(name, value, scanner.spanFrom(start));
    }
  }

  /// Tries to parse a namespaced [VariableDeclaration], and returns the value
  /// parsed so far if it fails.
  ///
  /// This can return either an [Interpolation], indicating that it couldn't
  /// consume a variable declaration and that property declaration or selector
  /// parsing should be attempted; or it can return a [VariableDeclaration],
  /// indicating that it successfully consumed a variable declaration.
  dynamic _variableDeclarationOrInterpolation() {
    if (!lookingAtIdentifier()) return interpolatedIdentifier();

    var start = scanner.state;
    var identifier = this.identifier();
    if (scanner.matches(".\$")) {
      scanner.readChar();
      return variableDeclarationWithoutNamespace(identifier, start);
    } else {
      var buffer = InterpolationBuffer()..write(identifier);

      // Parse the rest of an interpolated identifier if one exists, so callers
      // don't have to.
      if (_lookingAtInterpolatedIdentifierBody()) {
        buffer.addInterpolation(interpolatedIdentifier());
      }

      return buffer.interpolation(scanner.spanFrom(start));
    }
  }

  /// Consumes a [StyleRule], optionally with a [buffer] that may contain some
  /// text that has already been parsed.
  StyleRule _styleRule(
      [InterpolationBuffer? buffer, LineScannerState? start_]) {
    _isUseAllowed = false;
    var start = start_ ?? scanner.state; // dart-lang/sdk#45348

    var interpolation = styleRuleSelector();
    if (buffer != null) {
      buffer.addInterpolation(interpolation);
      interpolation = buffer.interpolation(scanner.spanFrom(start));
    }
    if (interpolation.contents.isEmpty) scanner.error('expected "}".');

    var wasInStyleRule = _inStyleRule;
    _inStyleRule = true;

    return _withChildren(_statement, start, (children, span) {
      if (indented && children.isEmpty) {
        warn("This selector doesn't have any properties and won't be rendered.",
            interpolation.span);
      }

      _inStyleRule = wasInStyleRule;

      return StyleRule(interpolation, children, scanner.spanFrom(start));
    });
  }

  /// Consumes either a property declaration or a namespaced variable
  /// declaration.
  ///
  /// This is only used in contexts where declarations are allowed but style
  /// rules are not, such as nested declarations. Otherwise,
  /// [_declarationOrStyleRule] is used instead.
  ///
  /// If [parseCustomProperties] is `true`, properties that begin with `--` will
  /// be parsed using custom property parsing rules.
  Statement _propertyOrVariableDeclaration(
      {bool parseCustomProperties = true}) {
    var start = scanner.state;

    Interpolation name;
    // Allow the "*prop: val", ":prop: val", "#prop: val", and ".prop: val"
    // hacks.
    var first = scanner.peekChar();
    if (first == $colon ||
        first == $asterisk ||
        first == $dot ||
        (first == $hash && scanner.peekChar(1) != $lbrace)) {
      var nameBuffer = InterpolationBuffer();
      nameBuffer.writeCharCode(scanner.readChar());
      nameBuffer.write(rawText(whitespace));
      nameBuffer.addInterpolation(interpolatedIdentifier());
      name = nameBuffer.interpolation(scanner.spanFrom(start));
    } else if (!plainCss) {
      var variableOrInterpolation = _variableDeclarationOrInterpolation();
      if (variableOrInterpolation is VariableDeclaration) {
        return variableOrInterpolation;
      } else {
        name = variableOrInterpolation as Interpolation;
      }
    } else {
      name = interpolatedIdentifier();
    }

    whitespace();
    scanner.expectChar($colon);

    if (parseCustomProperties && name.initialPlain.startsWith('--')) {
      var value = StringExpression(_interpolatedDeclarationValue());
      expectStatementSeparator("custom property");
      return Declaration(name, value, scanner.spanFrom(start));
    }

    whitespace();

    if (lookingAtChildren()) {
      if (plainCss) {
        scanner.error("Nested declarations aren't allowed in plain CSS.");
      }
      return _withChildren(_declarationChild, start,
          (children, span) => Declaration.nested(name, children, span));
    }

    var value = _expression();
    if (lookingAtChildren()) {
      if (plainCss) {
        scanner.error("Nested declarations aren't allowed in plain CSS.");
      }
      return _withChildren(
          _declarationChild,
          start,
          (children, span) =>
              Declaration.nested(name, children, span, value: value));
    } else {
      expectStatementSeparator();
      return Declaration(name, value, scanner.spanFrom(start));
    }
  }

  /// Consumes a statement that's allowed within a declaration.
  Statement _declarationChild() {
    if (scanner.peekChar() == $at) return _declarationAtRule();
    return _propertyOrVariableDeclaration(parseCustomProperties: false);
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
  @protected
  Statement atRule(Statement child(), {bool root = false}) {
    // NOTE: this logic is largely duplicated in CssParser.atRule. Most changes
    // here should be mirrored there.

    var start = scanner.state;
    scanner.expectChar($at, name: "@-rule");
    var name = interpolatedIdentifier();
    whitespace();

    // We want to set [_isUseAllowed] to `false` *unless* we're parsing
    // `@charset`, `@forward`, or `@use`. To avoid double-comparing the rule
    // name, we always set it to `false` and then set it back to its previous
    // value if we're parsing an allowed rule.
    var wasUseAllowed = _isUseAllowed;
    _isUseAllowed = false;

    switch (name.asPlain) {
      case "at-root":
        return _atRootRule(start);
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
      case "forward":
        _isUseAllowed = wasUseAllowed;
        if (!root) _disallowedAtRule(start);
        return _forwardRule(start);
      case "function":
        return _functionRule(start);
      case "if":
        return _ifRule(start, child);
      case "import":
        return _importRule(start);
      case "include":
        return _includeRule(start);
      case "media":
        return mediaRule(start);
      case "mixin":
        return _mixinRule(start);
      case "-moz-document":
        return mozDocumentRule(start, name);
      case "return":
        return _disallowedAtRule(start);
      case "supports":
        return supportsRule(start);
      case "use":
        _isUseAllowed = wasUseAllowed;
        if (!root) _disallowedAtRule(start);
        return _useRule(start);
      case "warn":
        return _warnRule(start);
      case "while":
        return _whileRule(start, child);
      default:
        return unknownAtRule(start, name);
    }
  }

  /// Consumes an at-rule allowed within a property declaration.
  Statement _declarationAtRule() {
    var start = scanner.state;
    var name = _plainAtRuleName();

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
        return _forRule(start, _declarationChild);
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

  /// Consumes a statement allowed within a function.
  Statement _functionChild() {
    if (scanner.peekChar() != $at) {
      var state = scanner.state;
      try {
        return _variableDeclarationWithNamespace();
      } on SourceSpanFormatException catch (variableDeclarationError, stackTrace) {
        scanner.state = state;

        // If a variable declaration failed to parse, it's possible the user
        // thought they could write a style rule or property declaration in a
        // function. If so, throw a more helpful error message.
        Statement statement;
        try {
          statement = _declarationOrStyleRule();
        } on SourceSpanFormatException catch (_) {
          throw variableDeclarationError;
        }

        error(
            "@function rules may not contain "
            "${statement is StyleRule ? "style rules" : "declarations"}.",
            statement.span,
            stackTrace);
      }
    }

    var start = scanner.state;
    switch (_plainAtRuleName()) {
      case "debug":
        return _debugRule(start);
      case "each":
        return _eachRule(start, _functionChild);
      case "else":
        return _disallowedAtRule(start);
      case "error":
        return _errorRule(start);
      case "for":
        return _forRule(start, _functionChild);
      case "if":
        return _ifRule(start, _functionChild);
      case "return":
        return _returnRule(start);
      case "warn":
        return _warnRule(start);
      case "while":
        return _whileRule(start, _functionChild);
      default:
        return _disallowedAtRule(start);
    }
  }

  /// Consumes an at-rule's name, with interpolation disallowed.
  String _plainAtRuleName() {
    scanner.expectChar($at, name: "@-rule");
    var name = identifier();
    whitespace();
    return name;
  }

  /// Consumes an `@at-root` rule.
  ///
  /// [start] should point before the `@`.
  AtRootRule _atRootRule(LineScannerState start) {
    if (scanner.peekChar() == $lparen) {
      var query = _atRootQuery();
      whitespace();
      return _withChildren(_statement, start,
          (children, span) => AtRootRule(children, span, query: query));
    } else if (lookingAtChildren()) {
      return _withChildren(
          _statement, start, (children, span) => AtRootRule(children, span));
    } else {
      var child = _styleRule();
      return AtRootRule([child], scanner.spanFrom(start));
    }
  }

  /// Consumes a query expression of the form `(foo: bar)`.
  Interpolation _atRootQuery() {
    if (scanner.peekChar() == $hash) {
      var interpolation = singleInterpolation();
      return Interpolation([interpolation], interpolation.span);
    }

    var start = scanner.state;
    var buffer = InterpolationBuffer();
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

  /// Consumes a `@content` rule.
  ///
  /// [start] should point before the `@`.
  ContentRule _contentRule(LineScannerState start) {
    if (!_inMixin) {
      error("@content is only allowed within mixin declarations.",
          scanner.spanFrom(start));
    }

    whitespace();
    var arguments = scanner.peekChar() == $lparen
        ? _argumentInvocation(mixin: true)
        : ArgumentInvocation.empty(scanner.emptySpan);

    expectStatementSeparator("@content rule");
    return ContentRule(arguments, scanner.spanFrom(start));
  }

  /// Consumes a `@debug` rule.
  ///
  /// [start] should point before the `@`.
  DebugRule _debugRule(LineScannerState start) {
    var value = _expression();
    expectStatementSeparator("@debug rule");
    return DebugRule(value, scanner.spanFrom(start));
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

    return _withChildren(child, start, (children, span) {
      _inControlDirective = wasInControlDirective;
      return EachRule(variables, list, children, span);
    });
  }

  /// Consumes an `@error` rule.
  ///
  /// [start] should point before the `@`.
  ErrorRule _errorRule(LineScannerState start) {
    var value = _expression();
    expectStatementSeparator("@error rule");
    return ErrorRule(value, scanner.spanFrom(start));
  }

  /// Consumes an `@extend` rule.
  ///
  /// [start] should point before the `@`.
  ExtendRule _extendRule(LineScannerState start) {
    if (!_inStyleRule && !_inMixin && !_inContentBlock) {
      error("@extend may only be used within style rules.",
          scanner.spanFrom(start));
    }

    var value = almostAnyValue();
    var optional = scanner.scanChar($exclamation);
    if (optional) expectIdentifier("optional");
    expectStatementSeparator("@extend rule");
    return ExtendRule(value, scanner.spanFrom(start), optional: optional);
  }

  /// Consumes a function declaration.
  ///
  /// [start] should point before the `@`.
  FunctionRule _functionRule(LineScannerState start) {
    var precedingComment = lastSilentComment;
    lastSilentComment = null;
    var name = identifier(normalize: true);
    whitespace();
    var arguments = _argumentDeclaration();

    if (_inMixin || _inContentBlock) {
      error("Mixins may not contain function declarations.",
          scanner.spanFrom(start));
    } else if (_inControlDirective) {
      error("Functions may not be declared in control directives.",
          scanner.spanFrom(start));
    }

    switch (unvendor(name)) {
      case "calc":
      case "element":
      case "expression":
      case "url":
      case "and":
      case "or":
      case "not":
      case "clamp":
        error("Invalid function name.", scanner.spanFrom(start));
    }

    whitespace();
    return _withChildren(
        _functionChild,
        start,
        (children, span) => FunctionRule(name, arguments, children, span,
            comment: precedingComment));
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

    bool? exclusive;
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

    return _withChildren(child, start, (children, span) {
      _inControlDirective = wasInControlDirective;
      return ForRule(variable, from, to, children, span,
          exclusive: exclusive!); // dart-lang/sdk#45348
    });
  }

  /// Consumes a `@forward` rule.
  ///
  /// [start] should point before the `@`.
  ForwardRule _forwardRule(LineScannerState start) {
    var url = _urlString();
    whitespace();

    String? prefix;
    if (scanIdentifier("as")) {
      whitespace();
      prefix = identifier(normalize: true);
      scanner.expectChar($asterisk);
      whitespace();
    }

    Set<String>? shownMixinsAndFunctions;
    Set<String>? shownVariables;
    Set<String>? hiddenMixinsAndFunctions;
    Set<String>? hiddenVariables;
    if (scanIdentifier("show")) {
      var members = _memberList();
      shownMixinsAndFunctions = members.item1;
      shownVariables = members.item2;
    } else if (scanIdentifier("hide")) {
      var members = _memberList();
      hiddenMixinsAndFunctions = members.item1;
      hiddenVariables = members.item2;
    }

    var configuration = _configuration(allowGuarded: true);

    expectStatementSeparator("@forward rule");
    var span = scanner.spanFrom(start);
    if (!_isUseAllowed) {
      error("@forward rules must be written before any other rules.", span);
    }

    if (shownMixinsAndFunctions != null) {
      return ForwardRule.show(
          url, shownMixinsAndFunctions, shownVariables!, span,
          prefix: prefix, configuration: configuration);
    } else if (hiddenMixinsAndFunctions != null) {
      return ForwardRule.hide(
          url, hiddenMixinsAndFunctions, hiddenVariables!, span,
          prefix: prefix, configuration: configuration);
    } else {
      return ForwardRule(url, span,
          prefix: prefix, configuration: configuration);
    }
  }

  /// Consumes a list of members that may contain either plain identifiers or
  /// variable names.
  ///
  /// The plain identifiers are returned in the first set, and the variable
  /// names in the second.
  Tuple2<Set<String>, Set<String>> _memberList() {
    var identifiers = <String>{};
    var variables = <String>{};
    do {
      whitespace();
      withErrorMessage("Expected variable, mixin, or function name", () {
        if (scanner.peekChar() == $dollar) {
          variables.add(variableName());
        } else {
          identifiers.add(identifier(normalize: true));
        }
      });
      whitespace();
    } while (scanner.scanChar($comma));

    return Tuple2(identifiers, variables);
  }

  /// Consumes an `@if` rule.
  ///
  /// [start] should point before the `@`. [child] is called to consume any
  /// children that are specifically allowed in the caller's context.
  IfRule _ifRule(LineScannerState start, Statement child()) {
    var ifIndentation = currentIndentation;
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var condition = _expression();
    var children = this.children(child);
    whitespaceWithoutComments();

    var clauses = [IfClause(condition, children)];
    ElseClause? lastClause;

    while (scanElse(ifIndentation)) {
      whitespace();
      if (scanIdentifier("if")) {
        whitespace();
        clauses.add(IfClause(_expression(), this.children(child)));
      } else {
        lastClause = ElseClause(this.children(child));
        break;
      }
    }
    _inControlDirective = wasInControlDirective;

    var span = scanner.spanFrom(start);
    whitespaceWithoutComments();
    return IfRule(clauses, span, lastClause: lastClause);
  }

  /// Consumes an `@import` rule.
  ///
  /// [start] should point before the `@`.
  ImportRule _importRule(LineScannerState start) {
    var imports = <Import>[];
    do {
      whitespace();
      var argument = importArgument();
      if ((_inControlDirective || _inMixin) && argument is DynamicImport) {
        _disallowedAtRule(start);
      }

      imports.add(argument);
      whitespace();
    } while (scanner.scanChar($comma));
    expectStatementSeparator("@import rule");

    return ImportRule(imports, scanner.spanFrom(start));
  }

  /// Consumes an argument to an `@import` rule.
  ///
  /// [ruleStart] should point before the `@`.
  @protected
  Import importArgument() {
    var start = scanner.state;
    var next = scanner.peekChar();
    if (next == $u || next == $U) {
      var url = dynamicUrl();
      whitespace();
      var modifiers = tryImportModifiers();
      return StaticImport(Interpolation([url], scanner.spanFrom(start)),
          scanner.spanFrom(start),
          modifiers: modifiers);
    }

    var url = string();
    var urlSpan = scanner.spanFrom(start);
    whitespace();
    var modifiers = tryImportModifiers();
    if (isPlainImportUrl(url) || modifiers != null) {
      return StaticImport(
          Interpolation([urlSpan.text], urlSpan), scanner.spanFrom(start),
          modifiers: modifiers);
    } else {
      try {
        return DynamicImport(parseImportUrl(url), urlSpan);
      } on FormatException catch (innerError, stackTrace) {
        error("Invalid URL: ${innerError.message}", urlSpan, stackTrace);
      }
    }
  }

  /// Parses [url] as an import URL.
  @protected
  String parseImportUrl(String url) {
    // Backwards-compatibility for implementations that allow absolute Windows
    // paths in imports.
    if (p.windows.isAbsolute(url) && !p.url.isRootRelative(url)) {
      return p.windows.toUri(url).toString();
    }

    // Throw a [FormatException] if [url] is invalid.
    Uri.parse(url);
    return url;
  }

  /// Returns whether [url] indicates that an `@import` is a plain CSS import.
  @protected
  bool isPlainImportUrl(String url) {
    if (url.length < 5) return false;
    if (url.endsWith(".css")) return true;

    var first = url.codeUnitAt(0);
    if (first == $slash) return url.codeUnitAt(1) == $slash;
    if (first != $h) return false;
    return url.startsWith("http://") || url.startsWith("https://");
  }

  /// Consumes a sequence of modifiers (such as media or supports queries)
  /// after an import argument.
  ///
  /// Returns `null` if there are no modifiers.
  Interpolation? tryImportModifiers() {
    // Exit before allocating anything if we're not looking at any modifiers, as
    // is the most common case.
    if (!_lookingAtInterpolatedIdentifier() && scanner.peekChar() != $lparen) {
      return null;
    }

    var start = scanner.state;
    var buffer = InterpolationBuffer();
    while (true) {
      if (_lookingAtInterpolatedIdentifier()) {
        if (!buffer.isEmpty) buffer.writeCharCode($space);

        var identifier = interpolatedIdentifier();
        buffer.addInterpolation(identifier);

        var name = identifier.asPlain?.toLowerCase();
        if (name != "and" && scanner.scanChar($lparen)) {
          if (name == "supports") {
            var query = _importSupportsQuery();
            if (query is! SupportsDeclaration) buffer.writeCharCode($lparen);
            buffer.add(SupportsExpression(query));
            if (query is! SupportsDeclaration) buffer.writeCharCode($rparen);
          } else {
            buffer.writeCharCode($lparen);
            buffer.addInterpolation(_interpolatedDeclarationValue(
                allowEmpty: true, allowSemicolon: true));
            buffer.writeCharCode($rparen);
          }

          scanner.expectChar($rparen);
          whitespace();
        } else {
          whitespace();
          if (scanner.scanChar($comma)) {
            buffer.write(", ");
            buffer.addInterpolation(_mediaQueryList());
            return buffer.interpolation(scanner.spanFrom(start));
          }
        }
      } else if (scanner.peekChar() == $lparen) {
        if (!buffer.isEmpty) buffer.writeCharCode($space);
        buffer.addInterpolation(_mediaQueryList());
        return buffer.interpolation(scanner.spanFrom(start));
      } else {
        return buffer.interpolation(scanner.spanFrom(start));
      }
    }
  }

  /// Consumes the contents of a `supports()` function after an `@import` rule
  /// (but not the function name or parentheses).
  SupportsCondition _importSupportsQuery() {
    if (scanIdentifier("not")) {
      whitespace();
      var start = scanner.state;
      return SupportsNegation(
          _supportsConditionInParens(), scanner.spanFrom(start));
    } else if (scanner.peekChar() == $lparen) {
      return _supportsCondition();
    } else {
      var function = _tryImportSupportsFunction();
      if (function != null) return function;

      var start = scanner.state;
      var name = _expression();
      scanner.expectChar($colon);
      return _supportsDeclarationValue(name, start);
    }
  }

  /// Consumes a function call within a `supports()` function after an
  /// `@import` if available.
  SupportsFunction? _tryImportSupportsFunction() {
    if (!_lookingAtInterpolatedIdentifier()) return null;

    var start = scanner.state;
    var name = interpolatedIdentifier();
    assert(name.asPlain != "not");

    if (!scanner.scanChar($lparen)) {
      scanner.state = start;
      return null;
    }

    var value =
        _interpolatedDeclarationValue(allowEmpty: true, allowSemicolon: true);
    scanner.expectChar($rparen);

    return SupportsFunction(name, value, scanner.spanFrom(start));
  }

  /// Consumes an `@include` rule.
  ///
  /// [start] should point before the `@`.
  IncludeRule _includeRule(LineScannerState start) {
    String? namespace;
    var name = identifier();
    if (scanner.scanChar($dot)) {
      namespace = name;
      name = _publicIdentifier();
    } else {
      name = name.replaceAll("_", "-");
    }

    whitespace();
    var arguments = scanner.peekChar() == $lparen
        ? _argumentInvocation(mixin: true)
        : ArgumentInvocation.empty(scanner.emptySpan);
    whitespace();

    ArgumentDeclaration? contentArguments;
    if (scanIdentifier("using")) {
      whitespace();
      contentArguments = _argumentDeclaration();
      whitespace();
    }

    ContentBlock? content;
    if (contentArguments != null || lookingAtChildren()) {
      var contentArguments_ =
          contentArguments ?? ArgumentDeclaration.empty(scanner.emptySpan);
      var wasInContentBlock = _inContentBlock;
      _inContentBlock = true;
      content = _withChildren(_statement, start,
          (children, span) => ContentBlock(contentArguments_, children, span));
      _inContentBlock = wasInContentBlock;
    } else {
      expectStatementSeparator();
    }

    var span =
        scanner.spanFrom(start, start).expand((content ?? arguments).span);
    return IncludeRule(name, arguments, span,
        namespace: namespace, content: content);
  }

  /// Consumes a `@media` rule.
  ///
  /// [start] should point before the `@`.
  @protected
  MediaRule mediaRule(LineScannerState start) {
    var query = _mediaQueryList();
    return _withChildren(_statement, start,
        (children, span) => MediaRule(query, children, span));
  }

  /// Consumes a mixin declaration.
  ///
  /// [start] should point before the `@`.
  MixinRule _mixinRule(LineScannerState start) {
    var precedingComment = lastSilentComment;
    lastSilentComment = null;
    var name = identifier(normalize: true);
    whitespace();
    var arguments = scanner.peekChar() == $lparen
        ? _argumentDeclaration()
        : ArgumentDeclaration.empty(scanner.emptySpan);

    if (_inMixin || _inContentBlock) {
      error("Mixins may not contain mixin declarations.",
          scanner.spanFrom(start));
    } else if (_inControlDirective) {
      error("Mixins may not be declared in control directives.",
          scanner.spanFrom(start));
    }

    whitespace();
    _inMixin = true;

    return _withChildren(_statement, start, (children, span) {
      _inMixin = false;
      return MixinRule(name, arguments, children, span,
          comment: precedingComment);
    });
  }

  /// Consumes a `@moz-document` rule.
  ///
  /// Gecko's `@-moz-document` diverges from [the specification][] allows the
  /// `url-prefix` and `domain` functions to omit quotation marks, contrary to
  /// the standard.
  ///
  /// [the specification]: http://www.w3.org/TR/css3-conditional/
  @protected
  AtRule mozDocumentRule(LineScannerState start, Interpolation name) {
    var valueStart = scanner.state;
    var buffer = InterpolationBuffer();
    var needsDeprecationWarning = false;
    while (true) {
      if (scanner.peekChar() == $hash) {
        buffer.add(singleInterpolation());
        needsDeprecationWarning = true;
      } else {
        var identifierStart = scanner.state;
        var identifier = this.identifier();
        switch (identifier) {
          case "url":
          case "url-prefix":
          case "domain":
            var contents = _tryUrlContents(identifierStart, name: identifier);
            if (contents != null) {
              buffer.addInterpolation(contents);
            } else {
              scanner.expectChar($lparen);
              whitespace();
              var argument = interpolatedString();
              scanner.expectChar($rparen);

              buffer
                ..write(identifier)
                ..writeCharCode($lparen)
                ..addInterpolation(argument.asInterpolation())
                ..writeCharCode($rparen);
            }

            // A url-prefix with no argument, or with an empty string as an
            // argument, is not (yet) deprecated.
            var trailing = buffer.trailingString;
            if (!trailing.endsWith("url-prefix()") &&
                !trailing.endsWith("url-prefix('')") &&
                !trailing.endsWith('url-prefix("")')) {
              needsDeprecationWarning = true;
            }
            break;

          case "regexp":
            buffer.write("regexp(");
            scanner.expectChar($lparen);
            buffer.addInterpolation(interpolatedString().asInterpolation());
            scanner.expectChar($rparen);
            buffer.writeCharCode($rparen);
            needsDeprecationWarning = true;
            break;

          default:
            error("Invalid function name.", scanner.spanFrom(identifierStart));
        }
      }

      whitespace();
      if (!scanner.scanChar($comma)) break;

      buffer.writeCharCode($comma);
      buffer.write(rawText(whitespace));
    }

    var value = buffer.interpolation(scanner.spanFrom(valueStart));
    return _withChildren(_statement, start, (children, span) {
      if (needsDeprecationWarning) {
        logger.warn(
            "@-moz-document is deprecated and support will be removed in Dart "
            "Sass 2.0.0.\n"
            "\n"
            "For details, see http://bit.ly/MozDocument.",
            span: span,
            deprecation: true);
      }

      return AtRule(name, span, value: value, children: children);
    });
  }

  /// Consumes a `@return` rule.
  ///
  /// [start] should point before the `@`.
  ReturnRule _returnRule(LineScannerState start) {
    var value = _expression();
    expectStatementSeparator("@return rule");
    return ReturnRule(value, scanner.spanFrom(start));
  }

  /// Consumes a `@supports` rule.
  ///
  /// [start] should point before the `@`.
  @protected
  SupportsRule supportsRule(LineScannerState start) {
    var condition = _supportsCondition();
    whitespace();
    return _withChildren(_statement, start,
        (children, span) => SupportsRule(condition, children, span));
  }

  /// Consumes a `@use` rule.
  ///
  /// [start] should point before the `@`.
  UseRule _useRule(LineScannerState start) {
    var url = _urlString();
    whitespace();

    var namespace = _useNamespace(url, start);
    whitespace();
    var configuration = _configuration();

    expectStatementSeparator("@use rule");

    var span = scanner.spanFrom(start);
    if (!_isUseAllowed) {
      error("@use rules must be written before any other rules.", span);
    }
    expectStatementSeparator("@use rule");

    return UseRule(url, namespace, span, configuration: configuration);
  }

  /// Parses the namespace of a `@use` rule from an `as` clause, or returns the
  /// default namespace from its URL.
  ///
  /// Returns `null` to indicate a `@use` rule without a URL.
  String? _useNamespace(Uri url, LineScannerState start) {
    if (scanIdentifier("as")) {
      whitespace();
      return scanner.scanChar($asterisk) ? null : identifier();
    }

    var basename = url.pathSegments.isEmpty ? "" : url.pathSegments.last;
    var dot = basename.indexOf(".");
    var namespace = basename.substring(
        basename.startsWith("_") ? 1 : 0, dot == -1 ? basename.length : dot);
    try {
      return Parser.parseIdentifier(namespace, logger: logger);
    } on SassFormatException {
      error(
          'The default namespace "$namespace" is not a valid Sass identifier.\n'
          "\n"
          'Recommendation: add an "as" clause to define an explicit namespace.',
          scanner.spanFrom(start));
    }
  }

  /// Returns the list of configured variables from a `@use` or `@forward`
  /// rule's `with` clause.
  ///
  /// If `allowGuarded` is `true`, this will allow configured variable with the
  /// `!default` flag.
  ///
  /// Returns `null` if there is no `with` clause.
  List<ConfiguredVariable>? _configuration({bool allowGuarded = false}) {
    if (!scanIdentifier("with")) return null;

    var variableNames = <String>{};
    var configuration = <ConfiguredVariable>[];
    whitespace();
    scanner.expectChar($lparen);

    while (true) {
      whitespace();

      var variableStart = scanner.state;
      var name = variableName();
      whitespace();
      scanner.expectChar($colon);
      whitespace();
      var expression = expressionUntilComma();

      var guarded = false;
      var flagStart = scanner.state;
      if (allowGuarded && scanner.scanChar($exclamation)) {
        var flag = identifier();
        if (flag == 'default') {
          guarded = true;
          whitespace();
        } else {
          error("Invalid flag name.", scanner.spanFrom(flagStart));
        }
      }

      var span = scanner.spanFrom(variableStart);
      if (variableNames.contains(name)) {
        error("The same variable may only be configured once.", span);
      }
      variableNames.add(name);
      configuration
          .add(ConfiguredVariable(name, expression, span, guarded: guarded));

      if (!scanner.scanChar($comma)) break;
      whitespace();
      if (!_lookingAtExpression()) break;
    }

    scanner.expectChar($rparen);
    return configuration;
  }

  /// Consumes a `@warn` rule.
  ///
  /// [start] should point before the `@`.
  WarnRule _warnRule(LineScannerState start) {
    var value = _expression();
    expectStatementSeparator("@warn rule");
    return WarnRule(value, scanner.spanFrom(start));
  }

  /// Consumes a `@while` rule.
  ///
  /// [start] should point before the `@`. [child] is called to consume any
  /// children that are specifically allowed in the caller's context.
  WhileRule _whileRule(LineScannerState start, Statement child()) {
    var wasInControlDirective = _inControlDirective;
    _inControlDirective = true;
    var condition = _expression();
    return _withChildren(child, start, (children, span) {
      _inControlDirective = wasInControlDirective;
      return WhileRule(condition, children, span);
    });
  }

  /// Consumes an at-rule that's not explicitly supported by Sass.
  ///
  /// [start] should point before the `@`. [name] is the name of the at-rule.
  @protected
  AtRule unknownAtRule(LineScannerState start, Interpolation name) {
    var wasInUnknownAtRule = _inUnknownAtRule;
    _inUnknownAtRule = true;

    Interpolation? value;
    var next = scanner.peekChar();
    if (next != $exclamation && !atEndOfStatement()) value = almostAnyValue();

    AtRule rule;
    if (lookingAtChildren()) {
      rule = _withChildren(
          _statement,
          start,
          (children, span) =>
              AtRule(name, span, value: value, children: children));
    } else {
      expectStatementSeparator();
      rule = AtRule(name, scanner.spanFrom(start), value: value);
    }

    _inUnknownAtRule = wasInUnknownAtRule;
    return rule;
  }

  /// Throws a [StringScannerException] indicating that the at-rule starting at
  /// [start] is not allowed in the current context.
  ///
  /// This declares a return type of [Statement] so that it can be returned
  /// within case statements.
  Statement _disallowedAtRule(LineScannerState start) {
    almostAnyValue();
    error("This at-rule is not allowed here.", scanner.spanFrom(start));
  }

  /// Consumes an argument declaration.
  ArgumentDeclaration _argumentDeclaration() {
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();
    var arguments = <Argument>[];
    var named = <String>{};
    String? restArgument;
    while (scanner.peekChar() == $dollar) {
      var variableStart = scanner.state;
      var name = variableName();
      whitespace();

      Expression? defaultValue;
      if (scanner.scanChar($colon)) {
        whitespace();
        defaultValue = expressionUntilComma();
      } else if (scanner.scanChar($dot)) {
        scanner.expectChar($dot);
        scanner.expectChar($dot);
        whitespace();
        restArgument = name;
        break;
      }

      arguments.add(Argument(name, scanner.spanFrom(variableStart),
          defaultValue: defaultValue));
      if (!named.add(name)) {
        error("Duplicate argument.", arguments.last.span);
      }

      if (!scanner.scanChar($comma)) break;
      whitespace();
    }
    scanner.expectChar($rparen);
    return ArgumentDeclaration(arguments, scanner.spanFrom(start),
        restArgument: restArgument);
  }

  // ## Expressions

  /// Consumes an argument invocation.
  ///
  /// If [mixin] is `true`, this is parsed as a mixin invocation. Mixin
  /// invocations don't allow the Microsoft-style `=` operator at the top level,
  /// but function invocations do.
  ///
  /// If [allowEmptySecondArg] is `true`, this allows the second argument to be
  /// omitted, in which case an unquoted empty string will be passed in its
  /// place.
  ArgumentInvocation _argumentInvocation(
      {bool mixin = false, bool allowEmptySecondArg = false}) {
    var start = scanner.state;
    scanner.expectChar($lparen);
    whitespace();

    var positional = <Expression>[];
    var named = <String, Expression>{};
    Expression? rest;
    Expression? keywordRest;
    while (_lookingAtExpression()) {
      var expression = expressionUntilComma(singleEquals: !mixin);
      whitespace();

      if (expression is VariableExpression && scanner.scanChar($colon)) {
        whitespace();
        if (named.containsKey(expression.name)) {
          error("Duplicate argument.", expression.span);
        }
        named[expression.name] = expressionUntilComma(singleEquals: !mixin);
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
        error("Positional arguments must come before keyword arguments.",
            expression.span);
      } else {
        positional.add(expression);
      }

      whitespace();
      if (!scanner.scanChar($comma)) break;
      whitespace();

      if (allowEmptySecondArg &&
          positional.length == 1 &&
          named.isEmpty &&
          rest == null &&
          scanner.peekChar() == $rparen) {
        positional.add(StringExpression.plain('', scanner.emptySpan));
        break;
      }
    }
    scanner.expectChar($rparen);

    return ArgumentInvocation(positional, named, scanner.spanFrom(start),
        rest: rest, keywordRest: keywordRest);
  }

  /// Consumes an expression.
  ///
  /// If [bracketList] is true, parses this expression as the contents of a
  /// bracketed list.
  ///
  /// If [singleEquals] is true, allows the Microsoft-style `=` operator at the
  /// top level.
  ///
  /// If [until] is passed, it's called each time the expression could end and
  /// still be a valid expression. When it returns `true`, this returns the
  /// expression.
  @protected
  Expression _expression(
      {bool bracketList = false, bool singleEquals = false, bool until()?}) {
    if (until != null && until()) scanner.error("Expected expression.");

    LineScannerState? beforeBracket;
    if (bracketList) {
      beforeBracket = scanner.state;
      scanner.expectChar($lbracket);
      whitespace();

      if (scanner.scanChar($rbracket)) {
        return ListExpression(
            [], ListSeparator.undecided, scanner.spanFrom(beforeBracket),
            brackets: true);
      }
    }

    var start = scanner.state;
    var wasInParentheses = _inParentheses;

    // We use the convention below of referring to nullable variables that are
    // shared across anonymous functions in this method with a trailling
    // underscore. This allows us to copy them to non-underscored local
    // variables to make it easier for Dart's type system to reason about their
    // local nullability.

    List<Expression>? commaExpressions_;

    List<Expression>? spaceExpressions_;

    // Operators whose right-hand operands_ are not fully parsed yet, in order of
    // appearance in the document. Because a low-precedence operator will cause
    // parsing to finish for all preceding higher-precedence operators_, this is
    // naturally ordered from lowest to highest precedence.
    List<BinaryOperator>? operators_;

    // The left-hand sides of [operators_]. `operands_[n]` is the left-hand side
    // of `operators_[n]`.
    List<Expression>? operands_;

    /// Whether the single expression parsed so far may be interpreted as
    /// slash-separated numbers.
    var allowSlash = true;

    /// The leftmost expression that's been fully-parsed. This can be null in
    /// special cases where the expression begins with a sub-expression but has
    /// a later character that indicates that the outer expression isn't done,
    /// as here:
    ///
    ///     foo, bar
    ///         ^
    Expression? singleExpression_ = _singleExpression();

    // Resets the scanner state to the state it was at at the beginning of the
    // expression, except for [_inParentheses].
    void resetState() {
      commaExpressions_ = null;
      spaceExpressions_ = null;
      operators_ = null;
      operands_ = null;
      scanner.state = start;
      allowSlash = true;
      singleExpression_ = _singleExpression();
    }

    void resolveOneOperation() {
      var operator = operators_!.removeLast();
      var operands = operands_!;

      var left = operands.removeLast();
      var right = singleExpression_;
      if (right == null) {
        scanner.error("Expected expression.",
            position: scanner.position - operator.operator.length,
            length: operator.operator.length);
      }

      if (allowSlash &&
          !_inParentheses &&
          operator == BinaryOperator.dividedBy &&
          _isSlashOperand(left) &&
          _isSlashOperand(right)) {
        singleExpression_ = BinaryOperationExpression.slash(left, right);
      } else {
        singleExpression_ = BinaryOperationExpression(operator, left, right);
        allowSlash = false;
      }
    }

    void resolveOperations() {
      var operators = operators_;
      if (operators == null) return;
      while (operators.isNotEmpty) {
        resolveOneOperation();
      }
    }

    void addSingleExpression(Expression expression) {
      if (singleExpression_ != null) {
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

        var spaceExpressions = spaceExpressions_ ??= [];
        resolveOperations();

        // [singleExpression_] was non-null before, and [resolveOperations]
        // can't make it null, it can only change it.
        spaceExpressions.add(singleExpression_!);
        allowSlash = true;
      }

      singleExpression_ = expression;
    }

    void addOperator(BinaryOperator operator) {
      if (plainCss &&
          operator != BinaryOperator.dividedBy &&
          operator != BinaryOperator.singleEquals) {
        scanner.error("Operators aren't allowed in plain CSS.",
            position: scanner.position - operator.operator.length,
            length: operator.operator.length);
      }

      allowSlash = allowSlash && operator == BinaryOperator.dividedBy;

      var operators = operators_ ??= [];
      var operands = operands_ ??= [];
      while (operators.isNotEmpty &&
          operators.last.precedence >= operator.precedence) {
        resolveOneOperation();
      }
      operators.add(operator);

      var singleExpression = singleExpression_;
      if (singleExpression == null) {
        scanner.error("Expected expression.",
            position: scanner.position - operator.operator.length,
            length: operator.operator.length);
      }
      operands.add(singleExpression);

      whitespace();
      singleExpression_ = _singleExpression();
    }

    void resolveSpaceExpressions() {
      resolveOperations();

      var spaceExpressions = spaceExpressions_;
      if (spaceExpressions != null) {
        var singleExpression = singleExpression_;
        if (singleExpression == null) scanner.error("Expected expression.");

        spaceExpressions.add(singleExpression);
        singleExpression_ = ListExpression(
            spaceExpressions,
            ListSeparator.space,
            spaceExpressions.first.span.expand(singleExpression.span));
        spaceExpressions_ = null;
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
            addOperator(BinaryOperator.singleEquals);
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
          if (singleExpression_ == null) {
            addSingleExpression(_unaryOperation());
          } else {
            scanner.readChar();
            addOperator(BinaryOperator.plus);
          }
          break;

        case $minus:
          var next = scanner.peekChar(1);
          if ((isDigit(next) || next == $dot) &&
              // Make sure `1-2` parses as `1 - 2`, not `1 (-2)`.
              (singleExpression_ == null ||
                  isWhitespace(scanner.peekChar(-1)))) {
            addSingleExpression(_number());
          } else if (_lookingAtInterpolatedIdentifier()) {
            addSingleExpression(identifierLike());
          } else if (singleExpression_ == null) {
            addSingleExpression(_unaryOperation());
          } else {
            scanner.readChar();
            addOperator(BinaryOperator.minus);
          }
          break;

        case $slash:
          if (singleExpression_ == null) {
            addSingleExpression(_unaryOperation());
          } else {
            scanner.readChar();
            addOperator(BinaryOperator.dividedBy);
          }
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
          if (!plainCss && scanIdentifier("and")) {
            addOperator(BinaryOperator.and);
          } else {
            addSingleExpression(identifierLike());
          }
          break;

        case $o:
          if (!plainCss && scanIdentifier("or")) {
            addOperator(BinaryOperator.or);
          } else {
            addSingleExpression(identifierLike());
          }
          break;

        case $u:
        case $U:
          if (scanner.peekChar(1) == $plus) {
            addSingleExpression(_unicodeRange());
          } else {
            addSingleExpression(identifierLike());
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
          addSingleExpression(identifierLike());
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

          var commaExpressions = commaExpressions_ ??= [];

          if (singleExpression_ == null) scanner.error("Expected expression.");
          resolveSpaceExpressions();

          // [resolveSpaceExpressions can modify [singleExpression_], but it
          // can't set it to null`.
          commaExpressions.add(singleExpression_!);

          scanner.readChar();
          allowSlash = true;
          singleExpression_ = null;
          break;

        default:
          if (first != null && first >= 0x80) {
            addSingleExpression(identifierLike());
            break;
          } else {
            break loop;
          }
      }
    }

    if (bracketList) scanner.expectChar($rbracket);

    var commaExpressions = commaExpressions_;
    var spaceExpressions = spaceExpressions_;
    if (commaExpressions != null) {
      resolveSpaceExpressions();
      _inParentheses = wasInParentheses;
      var singleExpression = singleExpression_;
      if (singleExpression != null) commaExpressions.add(singleExpression);
      return ListExpression(commaExpressions, ListSeparator.comma,
          scanner.spanFrom(beforeBracket ?? start),
          brackets: bracketList);
    } else if (bracketList && spaceExpressions != null) {
      resolveOperations();
      return ListExpression(spaceExpressions..add(singleExpression_!),
          ListSeparator.space, scanner.spanFrom(beforeBracket!),
          brackets: true);
    } else {
      resolveSpaceExpressions();
      if (bracketList) {
        singleExpression_ = ListExpression([singleExpression_!],
            ListSeparator.undecided, scanner.spanFrom(beforeBracket!),
            brackets: true);
      }
      return singleExpression_!;
    }
  }

  /// Consumes an expression until it reaches a top-level comma.
  ///
  /// If [singleEquals] is true, this will allow the Microsoft-style `=`
  /// operator at the top level.
  Expression expressionUntilComma({bool singleEquals = false}) => _expression(
      singleEquals: singleEquals, until: () => scanner.peekChar() == $comma);

  /// Whether [expression] is allowed as an operand of a `/` expression that
  /// produces a potentially slash-separated number.
  bool _isSlashOperand(Expression expression) =>
      expression is NumberExpression ||
      expression is CalculationExpression ||
      (expression is BinaryOperationExpression && expression.allowsSlash);

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
          return identifierLike();
        }

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
        return identifierLike();

      default:
        if (first != null && first >= 0x80) return identifierLike();
        scanner.error("Expected expression.");
    }
  }

  /// Consumes a parenthesized expression.
  Expression _parentheses() {
    if (plainCss) {
      scanner.error("Parentheses aren't allowed in plain CSS.", length: 1);
    }

    var wasInParentheses = _inParentheses;
    _inParentheses = true;
    try {
      var start = scanner.state;
      scanner.expectChar($lparen);
      whitespace();
      if (!_lookingAtExpression()) {
        scanner.expectChar($rparen);
        return ListExpression(
            [], ListSeparator.undecided, scanner.spanFrom(start));
      }

      var first = expressionUntilComma();
      if (scanner.scanChar($colon)) {
        whitespace();
        return _map(first, start);
      }

      if (!scanner.scanChar($comma)) {
        scanner.expectChar($rparen);
        return ParenthesizedExpression(first, scanner.spanFrom(start));
      }
      whitespace();

      var expressions = [first];
      while (true) {
        if (!_lookingAtExpression()) break;
        expressions.add(expressionUntilComma());
        if (!scanner.scanChar($comma)) break;
        whitespace();
      }

      scanner.expectChar($rparen);
      return ListExpression(
          expressions, ListSeparator.comma, scanner.spanFrom(start));
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
    var pairs = [Tuple2(first, expressionUntilComma())];

    while (scanner.scanChar($comma)) {
      whitespace();
      if (!_lookingAtExpression()) break;

      var key = expressionUntilComma();
      scanner.expectChar($colon);
      whitespace();
      var value = expressionUntilComma();
      pairs.add(Tuple2(key, value));
    }

    scanner.expectChar($rparen);
    return MapExpression(pairs, scanner.spanFrom(start));
  }

  /// Consumes an expression that starts with a `#`.
  Expression _hashExpression() {
    assert(scanner.peekChar() == $hash);
    if (scanner.peekChar(1) == $lbrace) return identifierLike();

    var start = scanner.state;
    scanner.expectChar($hash);

    var first = scanner.peekChar();
    if (first != null && isDigit(first)) {
      return ColorExpression(_hexColorContents(start), scanner.spanFrom(start));
    }

    var afterHash = scanner.state;
    var identifier = interpolatedIdentifier();
    if (_isHexColor(identifier)) {
      scanner.state = afterHash;
      return ColorExpression(_hexColorContents(start), scanner.spanFrom(start));
    }

    var buffer = InterpolationBuffer();
    buffer.writeCharCode($hash);
    buffer.addInterpolation(identifier);
    return StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  /// Consumes the contents of a hex color, after the `#`.
  SassColor _hexColorContents(LineScannerState start) {
    var digit1 = _hexDigit();
    var digit2 = _hexDigit();
    var digit3 = _hexDigit();

    int red;
    int green;
    int blue;
    num? alpha;
    if (!isHex(scanner.peekChar())) {
      // #abc
      red = (digit1 << 4) + digit1;
      green = (digit2 << 4) + digit2;
      blue = (digit3 << 4) + digit3;
    } else {
      var digit4 = _hexDigit();
      if (!isHex(scanner.peekChar())) {
        // #abcd
        red = (digit1 << 4) + digit1;
        green = (digit2 << 4) + digit2;
        blue = (digit3 << 4) + digit3;
        alpha = ((digit4 << 4) + digit4) / 0xff;
      } else {
        red = (digit1 << 4) + digit2;
        green = (digit3 << 4) + digit4;
        blue = (_hexDigit() << 4) + _hexDigit();

        if (isHex(scanner.peekChar())) {
          alpha = ((_hexDigit() << 4) + _hexDigit()) / 0xff;
        }
      }
    }

    return SassColor.rgbInternal(
        red,
        green,
        blue,
        alpha,
        // Don't emit four- or eight-digit hex colors as hex, since that's not
        // yet well-supported in browsers.
        alpha == null ? SpanColorFormat(scanner.spanFrom(start)) : null);
  }

  /// Returns whether [interpolation] is a plain string that can be parsed as a
  /// hex color.
  bool _isHexColor(Interpolation interpolation) {
    var plain = interpolation.asPlain;
    if (plain == null) return false;
    if (plain.length != 3 &&
        plain.length != 4 &&
        plain.length != 6 &&
        plain.length != 8) {
      return false;
    }
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
    if (_lookingAtInterpolatedIdentifier()) return identifierLike();
    return _unaryOperation();
  }

  /// Consumes an `!important` expression.
  Expression _importantExpression() {
    assert(scanner.peekChar() == $exclamation);

    var start = scanner.state;
    scanner.readChar();
    whitespace();
    expectIdentifier("important");
    return StringExpression.plain("!important", scanner.spanFrom(start));
  }

  /// Consumes a unary operation expression.
  UnaryOperationExpression _unaryOperation() {
    var start = scanner.state;
    var operator = _unaryOperatorFor(scanner.readChar());
    if (operator == null) {
      scanner.error("Expected unary operator.", position: scanner.position - 1);
    } else if (plainCss && operator != UnaryOperator.divide) {
      scanner.error("Operators aren't allowed in plain CSS.",
          position: scanner.position - 1, length: 1);
    }

    whitespace();
    var operand = _singleExpression();
    return UnaryOperationExpression(operator, operand, scanner.spanFrom(start));
  }

  /// Returns the unary operator corresponding to [character], or `null` if
  /// the character is not a unary operator.
  UnaryOperator? _unaryOperatorFor(int character) {
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
    var sign = first == $minus ? -1 : 1;
    if (first == $plus || first == $minus) scanner.readChar();

    num number = scanner.peekChar() == $dot ? 0 : naturalNumber();

    // Don't complain about a dot after a number unless the number starts with a
    // dot. We don't allow a plain ".", but we need to allow "1." so that
    // "1..." will work as a rest argument.
    number += _tryDecimal(allowTrailingDot: scanner.position != start.position);
    number *= _tryExponent();

    String? unit;
    if (scanner.scanChar($percent)) {
      unit = "%";
    } else if (lookingAtIdentifier() &&
        // Disallow units beginning with `--`.
        (scanner.peekChar() != $dash || scanner.peekChar(1) != $dash)) {
      unit = identifier(unit: true);
    }

    return NumberExpression(sign * number, scanner.spanFrom(start), unit: unit);
  }

  /// Consumes the decimal component of a number and returns its value, or 0 if
  /// there is no decimal component.
  ///
  /// If [allowTrailingDot] is `false`, this will throw an error if there's a
  /// dot without any numbers following it. Otherwise, it will ignore the dot
  /// without consuming it.
  num _tryDecimal({bool allowTrailingDot = false}) {
    var start = scanner.position;
    if (scanner.peekChar() != $dot) return 0;

    if (!isDigit(scanner.peekChar(1))) {
      if (allowTrailingDot) return 0;
      scanner.error("Expected digit.", position: scanner.position + 1);
    }

    scanner.readChar();
    while (isDigit(scanner.peekChar())) {
      scanner.readChar();
    }

    // Use Dart's built-in double parsing so that we don't accumulate
    // floating-point errors for numbers with lots of digits.
    return double.parse(scanner.substring(start));
  }

  /// Consumes the exponent component of a number and returns its value, or 1 if
  /// there is no exponent component.
  num _tryExponent() {
    var first = scanner.peekChar();
    if (first != $e && first != $E) return 1;

    var next = scanner.peekChar(1);
    if (!isDigit(next) && next != $minus && next != $plus) return 1;

    scanner.readChar();
    var exponentSign = next == $minus ? -1 : 1;
    if (next == $plus || next == $minus) scanner.readChar();
    if (!isDigit(scanner.peekChar())) scanner.error("Expected digit.");

    var exponent = 0.0;
    while (isDigit(scanner.peekChar())) {
      exponent *= 10;
      exponent += scanner.readChar() - $0;
    }

    return math.pow(10, exponentSign * exponent);
  }

  /// Consumes a unicode range expression.
  StringExpression _unicodeRange() {
    var start = scanner.state;
    expectIdentChar($u);
    scanner.expectChar($plus);

    var firstRangeLength = 0;
    while (scanCharIf((char) => char != null && isHex(char))) {
      firstRangeLength++;
    }

    var hasQuestionMark = false;
    while (scanner.scanChar($question)) {
      hasQuestionMark = true;
      firstRangeLength++;
    }

    if (firstRangeLength == 0) {
      scanner.error('Expected hex digit or "?".');
    } else if (firstRangeLength > 6) {
      error("Expected at most 6 digits.", scanner.spanFrom(start));
    } else if (hasQuestionMark) {
      return StringExpression.plain(
          scanner.substring(start.position), scanner.spanFrom(start));
    }

    if (scanner.scanChar($minus)) {
      var secondRangeStart = scanner.state;
      var secondRangeLength = 0;
      while (scanCharIf((char) => char != null && isHex(char))) {
        secondRangeLength++;
      }

      if (secondRangeLength == 0) {
        scanner.error("Expected hex digit.");
      } else if (secondRangeLength > 6) {
        error("Expected at most 6 digits.", scanner.spanFrom(secondRangeStart));
      }
    }

    if (_lookingAtInterpolatedIdentifierBody()) {
      scanner.error("Expected end of identifier.");
    }

    return StringExpression.plain(
        scanner.substring(start.position), scanner.spanFrom(start));
  }

  /// Consumes a variable expression.
  VariableExpression _variable() {
    var start = scanner.state;
    var name = variableName();

    if (plainCss) {
      error("Sass variables aren't allowed in plain CSS.",
          scanner.spanFrom(start));
    }

    return VariableExpression(name, scanner.spanFrom(start));
  }

  /// Consumes a selector expression.
  SelectorExpression _selector() {
    if (plainCss) {
      scanner.error("The parent selector isn't allowed in plain CSS.",
          length: 1);
    }

    var start = scanner.state;
    scanner.expectChar($ampersand);

    if (scanner.scanChar($ampersand)) {
      warn(
          'In Sass, "&&" means two copies of the parent selector. You '
          'probably want to use "and" instead.',
          scanner.spanFrom(start));
      scanner.position--;
    }

    return SelectorExpression(scanner.spanFrom(start));
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

    var buffer = InterpolationBuffer();
    while (true) {
      var next = scanner.peekChar();
      if (next == quote) {
        scanner.readChar();
        break;
      } else if (next == null || isNewline(next)) {
        scanner.error("Expected ${String.fromCharCode(quote)}.");
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

    return StringExpression(buffer.interpolation(scanner.spanFrom(start)),
        quotes: true);
  }

  /// Consumes an expression that starts like an identifier.
  @protected
  Expression identifierLike() {
    var start = scanner.state;
    var identifier = interpolatedIdentifier();
    var plain = identifier.asPlain;
    late String? lower;
    if (plain != null) {
      if (plain == "if" && scanner.peekChar() == $lparen) {
        var invocation = _argumentInvocation();
        return IfExpression(
            invocation, identifier.span.expand(invocation.span));
      } else if (plain == "not") {
        whitespace();
        return UnaryOperationExpression(
            UnaryOperator.not, _singleExpression(), identifier.span);
      }

      lower = plain.toLowerCase();
      if (scanner.peekChar() != $lparen) {
        switch (plain) {
          case "false":
            return BooleanExpression(false, identifier.span);
          case "null":
            return NullExpression(identifier.span);
          case "true":
            return BooleanExpression(true, identifier.span);
        }

        var color = colorsByName[lower];
        if (color != null) {
          color = SassColor.rgbInternal(color.red, color.green, color.blue,
              color.alpha, SpanColorFormat(identifier.span));
          return ColorExpression(color, identifier.span);
        }
      }

      var specialFunction = trySpecialFunction(lower, start);
      if (specialFunction != null) return specialFunction;
    }

    switch (scanner.peekChar()) {
      case $dot:
        if (scanner.peekChar(1) == $dot) return StringExpression(identifier);
        scanner.readChar();

        if (plain != null) return namespacedExpression(plain, start);
        error("Interpolation isn't allowed in namespaces.", identifier.span);

      case $lparen:
        if (plain == null) {
          return InterpolatedFunctionExpression(
              identifier, _argumentInvocation(), scanner.spanFrom(start));
        } else {
          return FunctionExpression(
              plain,
              _argumentInvocation(allowEmptySecondArg: lower == 'var'),
              scanner.spanFrom(start));
        }

      default:
        return StringExpression(identifier);
    }
  }

  /// Consumes an expression after a namespace.
  ///
  /// This assumes the scanner is positioned immediately after the `.`. The
  /// [start] should refer to the state at the beginning of the namespace.
  @protected
  Expression namespacedExpression(String namespace, LineScannerState start) {
    if (scanner.peekChar() == $dollar) {
      var name = variableName();
      _assertPublic(name, () => scanner.spanFrom(start));
      return VariableExpression(name, scanner.spanFrom(start),
          namespace: namespace);
    }

    return FunctionExpression(
        _publicIdentifier(), _argumentInvocation(), scanner.spanFrom(start),
        namespace: namespace);
  }

  /// If [name] is the name of a function with special syntax, consumes it.
  ///
  /// Otherwise, returns `null`. [start] is the location before the beginning of
  /// [name].
  @protected
  Expression? trySpecialFunction(String name, LineScannerState start) {
    var calculation =
        scanner.peekChar() == $lparen ? _tryCalculation(name, start) : null;
    if (calculation != null) return calculation;

    var normalized = unvendor(name);

    InterpolationBuffer buffer;
    switch (normalized) {
      case "calc":
      case "element":
      case "expression":
        if (!scanner.scanChar($lparen)) return null;
        buffer = InterpolationBuffer()
          ..write(name)
          ..writeCharCode($lparen);
        break;

      case "progid":
        if (!scanner.scanChar($colon)) return null;
        buffer = InterpolationBuffer()
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
        return _tryUrlContents(start)
            .andThen((contents) => StringExpression(contents));

      default:
        return null;
    }

    buffer.addInterpolation(_interpolatedDeclarationValue(allowEmpty: true));
    scanner.expectChar($rparen);
    buffer.writeCharCode($rparen);

    return StringExpression(buffer.interpolation(scanner.spanFrom(start)));
  }

  /// If [name] is the name of a calculation expression, parses the
  /// corresponding calculation and returns it.
  ///
  /// Assumes the scanner is positioned immediately before the opening
  /// parenthesis of the argument list.
  CalculationExpression? _tryCalculation(String name, LineScannerState start) {
    assert(scanner.peekChar() == $lparen);
    switch (name) {
      case "calc":
        var arguments = _calculationArguments(1);
        return CalculationExpression(name, arguments, scanner.spanFrom(start));

      case "min":
      case "max":
        // min() and max() are parsed as calculations if possible, and otherwise
        // are parsed as normal Sass functions.
        var beforeArguments = scanner.state;
        List<Expression> arguments;
        try {
          arguments = _calculationArguments();
        } on FormatException catch (_) {
          scanner.state = beforeArguments;
          return null;
        }

        return CalculationExpression(name, arguments, scanner.spanFrom(start));

      case "clamp":
        var arguments = _calculationArguments(3);
        return CalculationExpression(name, arguments, scanner.spanFrom(start));

      default:
        return null;
    }
  }

  /// Consumes and returns arguments for a calculation expression, including the
  /// opening and closing parentheses.
  ///
  /// If [maxArgs] is passed, at most that many arguments are consumed.
  /// Otherwise, any number greater than zero are consumed.
  List<Expression> _calculationArguments([int? maxArgs]) {
    scanner.expectChar($lparen);
    var interpolation = _tryCalculationInterpolation();
    if (interpolation != null) {
      scanner.expectChar($rparen);
      return [interpolation];
    }

    whitespace();
    var arguments = [_calculationSum()];
    while ((maxArgs == null || arguments.length < maxArgs) &&
        scanner.scanChar($comma)) {
      whitespace();
      arguments.add(_calculationSum());
    }

    scanner.expectChar($rparen,
        name: arguments.length == maxArgs
            ? '"+", "-", "*", "/", or ")"'
            : '"+", "-", "*", "/", ",", or ")"');

    return arguments;
  }

  /// Parses a calculation operation or value expression.
  Expression _calculationSum() {
    var sum = _calculationProduct();

    while (true) {
      var next = scanner.peekChar();
      if (next == $plus || next == $minus) {
        if (!isWhitespace(scanner.peekChar(-1)) ||
            !isWhitespace(scanner.peekChar(1))) {
          scanner.error(
              '"+" and "-" must be surrounded by whitespace in calculations.');
        }

        scanner.readChar();
        whitespace();
        sum = BinaryOperationExpression(
            next == $plus ? BinaryOperator.plus : BinaryOperator.minus,
            sum,
            _calculationProduct());
      } else {
        return sum;
      }
    }
  }

  /// Parses a calculation product or value expression.
  Expression _calculationProduct() {
    var product = _calculationValue();

    while (true) {
      whitespace();
      var next = scanner.peekChar();
      if (next == $asterisk || next == $slash) {
        scanner.readChar();
        whitespace();
        product = BinaryOperationExpression(
            next == $asterisk ? BinaryOperator.times : BinaryOperator.dividedBy,
            product,
            _calculationValue());
      } else {
        return product;
      }
    }
  }

  /// Parses a single calculation value.
  Expression _calculationValue() {
    var next = scanner.peekChar();
    if (next == $plus || next == $minus || next == $dot || isDigit(next)) {
      return _number();
    } else if (next == $dollar) {
      return _variable();
    } else if (next == $lparen) {
      var start = scanner.state;
      scanner.readChar();

      Expression? value = _tryCalculationInterpolation();
      if (value == null) {
        whitespace();
        value = _calculationSum();
      }

      whitespace();
      scanner.expectChar($rparen);
      return ParenthesizedExpression(value, scanner.spanFrom(start));
    } else if (!lookingAtIdentifier()) {
      scanner.error("Expected number, variable, function, or calculation.");
    } else {
      var start = scanner.state;
      var ident = identifier();
      if (scanner.scanChar($dot)) return namespacedExpression(ident, start);
      if (scanner.peekChar() != $lparen) scanner.error('Expected "(" or ".".');

      var lowerCase = ident.toLowerCase();
      var calculation = _tryCalculation(lowerCase, start);
      if (calculation != null) {
        return calculation;
      } else if (lowerCase == "if") {
        return IfExpression(_argumentInvocation(), scanner.spanFrom(start));
      } else {
        return FunctionExpression(
            ident, _argumentInvocation(), scanner.spanFrom(start));
      }
    }
  }

  /// If the following text up to the next unbalanced `")"`, `"]"`, or `"}"`
  /// contains interpolation, parses that interpolation as an unquoted
  /// [StringExpression] and returns it.
  StringExpression? _tryCalculationInterpolation() =>
      _containsCalculationInterpolation()
          ? StringExpression(_interpolatedDeclarationValue())
          : null;

  /// Returns whether the following text up to the next unbalanced `")"`, `"]"`,
  /// or `"}"` contains interpolation.
  bool _containsCalculationInterpolation() {
    var parens = 0;
    var brackets = <int>[];

    var start = scanner.state;
    while (!scanner.isDone) {
      var next = scanner.peekChar();
      switch (next) {
        case $backslash:
          scanner.readChar();
          scanner.readChar();
          break;

        case $slash:
          if (!scanComment()) scanner.readChar();
          break;

        case $single_quote:
        case $double_quote:
          interpolatedString();
          break;

        case $hash:
          if (parens == 0 && scanner.peekChar(1) == $lbrace) {
            scanner.state = start;
            return true;
          }
          scanner.readChar();
          break;

        case $lparen:
          parens++;
          continue left;

        left:
        case $lbrace:
        case $lbracket:
          // dart-lang/sdk#45357
          brackets.add(opposite(next!));
          scanner.readChar();
          break;

        case $rparen:
          parens--;
          continue right;

        right:
        case $rbrace:
        case $rbracket:
          if (brackets.isEmpty || brackets.removeLast() != next) {
            scanner.state = start;
            return false;
          }
          scanner.readChar();
          break;

        default:
          scanner.readChar();
      }
    }

    scanner.state = start;
    return false;
  }

  /// Like [_urlContents], but returns `null` if the URL fails to parse.
  ///
  /// [start] is the position before the beginning of the name. [name] is the
  /// function's name; it defaults to `"url"`.
  Interpolation? _tryUrlContents(LineScannerState start, {String? name}) {
    // NOTE: this logic is largely duplicated in Parser.tryUrl. Most changes
    // here should be mirrored there.

    var beginningOfContents = scanner.state;
    if (!scanner.scanChar($lparen)) return null;
    whitespaceWithoutComments();

    // Match Ruby Sass's behavior: parse a raw URL() if possible, and if not
    // backtrack and re-parse as a function expression.
    var buffer = InterpolationBuffer()
      ..write(name ?? 'url')
      ..writeCharCode($lparen);
    while (true) {
      var next = scanner.peekChar();
      if (next == null) {
        break;
      } else if (next == $backslash) {
        buffer.write(escape());
      } else if (next == $exclamation ||
          next == $percent ||
          next == $ampersand ||
          (next >= $asterisk && next <= $tilde) ||
          next >= 0x0080) {
        buffer.writeCharCode(scanner.readChar());
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

    scanner.state = beginningOfContents;
    return null;
  }

  /// Consumes a [url] token that's allowed to contain SassScript.
  @protected
  Expression dynamicUrl() {
    var start = scanner.state;
    expectIdentifier("url");
    var contents = _tryUrlContents(start);
    if (contents != null) return StringExpression(contents);

    return InterpolatedFunctionExpression(
        Interpolation(["url"], scanner.spanFrom(start)),
        _argumentInvocation(),
        scanner.spanFrom(start));
  }

  /// Consumes tokens up to "{", "}", ";", or "!".
  ///
  /// This respects string and comment boundaries and supports interpolation.
  /// Once this interpolation is evaluated, it's expected to be re-parsed.
  ///
  /// If [omitComments] is true, comments will still be consumed, but they will
  /// not be included in the returned interpolation.
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
  @protected
  Interpolation almostAnyValue({bool omitComments = false}) {
    var start = scanner.state;
    var buffer = InterpolationBuffer();

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
            if (!omitComments) buffer.write(scanner.substring(commentStart));
          } else {
            buffer.writeCharCode(scanner.readChar());
          }
          break;

        case $hash:
          if (scanner.peekChar(1) == $lbrace) {
            // Add a full interpolated identifier to handle cases like
            // "#{...}--1", since "--1" isn't a valid identifier on its own.
            buffer.addInterpolation(interpolatedIdentifier());
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
          if (!scanIdentifier("url")) {
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

  /// Consumes tokens until it reaches a top-level `";"`, `")"`, `"]"`,
  /// or `"}"` and returns their contents as a string.
  ///
  /// If [allowEmpty] is `false` (the default), this requires at least one token.
  ///
  /// If [allowSemicolon] is `true`, this doesn't stop at semicolons and instead
  /// includes them in the interpolated output.
  ///
  /// If [allowColon] is `false`, this stops at top-level colons.
  ///
  /// Unlike [declarationValue], this allows interpolation.
  Interpolation _interpolatedDeclarationValue(
      {bool allowEmpty = false,
      bool allowSemicolon = false,
      bool allowColon = true}) {
    // NOTE: this logic is largely duplicated in Parser.declarationValue. Most
    // changes here should be mirrored there.

    var start = scanner.state;
    var buffer = InterpolationBuffer();

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
            buffer.addInterpolation(interpolatedIdentifier());
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
          if (!allowSemicolon && brackets.isEmpty) break loop;
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;
          break;

        case $colon:
          if (!allowColon && brackets.isEmpty) break loop;
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;
          break;

        case $u:
        case $U:
          var beforeUrl = scanner.state;
          if (!scanIdentifier("url")) {
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
    if (!allowEmpty && buffer.isEmpty) scanner.error("Expected token.");
    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes an identifier that may contain interpolation.
  @protected
  Interpolation interpolatedIdentifier() {
    var start = scanner.state;
    var buffer = InterpolationBuffer();

    if (scanner.scanChar($dash)) {
      buffer.writeCharCode($dash);

      if (scanner.scanChar($dash)) {
        buffer.writeCharCode($dash);
        _interpolatedIdentifierBody(buffer);
        return buffer.interpolation(scanner.spanFrom(start));
      }
    }

    var first = scanner.peekChar();
    if (first == null) {
      scanner.error("Expected identifier.");
    } else if (isNameStart(first)) {
      buffer.writeCharCode(scanner.readChar());
    } else if (first == $backslash) {
      buffer.write(escape(identifierStart: true));
    } else if (first == $hash && scanner.peekChar(1) == $lbrace) {
      buffer.add(singleInterpolation());
    } else {
      scanner.error("Expected identifier.");
    }

    _interpolatedIdentifierBody(buffer);
    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes a chunk of a possibly-interpolated CSS identifier after the name
  /// start, and adds the contents to the [buffer] buffer.
  void _interpolatedIdentifierBody(InterpolationBuffer buffer) {
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
  }

  /// Consumes interpolation.
  @protected
  Expression singleInterpolation() {
    var start = scanner.state;
    scanner.expect('#{');
    whitespace();
    var contents = _expression();
    scanner.expectChar($rbrace);

    if (plainCss) {
      error(
          "Interpolation isn't allowed in plain CSS.", scanner.spanFrom(start));
    }

    return contents;
  }

  // ## Media Queries

  /// Consumes a list of media queries.
  Interpolation _mediaQueryList() {
    var start = scanner.state;
    var buffer = InterpolationBuffer();
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
      buffer.addInterpolation(interpolatedIdentifier());
      whitespace();

      if (!_lookingAtInterpolatedIdentifier()) {
        // For example, "@media screen {".
        return;
      }

      buffer.writeCharCode($space);
      var identifier = interpolatedIdentifier();
      whitespace();

      if (equalsIgnoreCase(identifier.asPlain, "and")) {
        // For example, "@media screen and ..."
        buffer.write(" and ");
      } else {
        buffer.addInterpolation(identifier);
        if (scanIdentifier("and")) {
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
      buffer.addInterpolation(_mediaFeature());
      whitespace();
      if (!scanIdentifier("and")) break;
      buffer.write(" and ");
    }
  }

  /// Consumes a media query feature.
  Interpolation _mediaFeature() {
    if (scanner.peekChar() == $hash) {
      var interpolation = singleInterpolation();
      return Interpolation([interpolation], interpolation.span);
    }

    var start = scanner.state;
    var buffer = InterpolationBuffer();
    scanner.expectChar($lparen);
    buffer.writeCharCode($lparen);
    whitespace();

    buffer.add(_expressionUntilComparison());
    if (scanner.scanChar($colon)) {
      whitespace();
      buffer.writeCharCode($colon);
      buffer.writeCharCode($space);
      buffer.add(_expression());
    } else {
      var next = scanner.peekChar();
      if (next == $langle || next == $rangle || next == $equal) {
        buffer.writeCharCode($space);
        buffer.writeCharCode(scanner.readChar());
        if ((next == $langle || next == $rangle) && scanner.scanChar($equal)) {
          buffer.writeCharCode($equal);
        }
        buffer.writeCharCode($space);

        whitespace();
        buffer.add(_expressionUntilComparison());

        if ((next == $langle || next == $rangle) &&
            // dart-lang/sdk#45356
            scanner.scanChar(next!)) {
          buffer.writeCharCode($space);
          buffer.writeCharCode(next);
          if (scanner.scanChar($equal)) buffer.writeCharCode($equal);
          buffer.writeCharCode($space);

          whitespace();
          buffer.add(_expressionUntilComparison());
        }
      }
    }

    scanner.expectChar($rparen);
    whitespace();
    buffer.writeCharCode($rparen);

    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes an expression until it reaches a top-level `<`, `>`, or a `=`
  /// that's not `==`.
  Expression _expressionUntilComparison() => _expression(until: () {
        var next = scanner.peekChar();
        if (next == $equal) return scanner.peekChar(1) != $equal;
        return next == $langle || next == $rangle;
      });

  // ## Supports Conditions

  /// Consumes a `@supports` condition.
  SupportsCondition _supportsCondition() {
    var start = scanner.state;
    if (scanIdentifier("not")) {
      whitespace();
      return SupportsNegation(
          _supportsConditionInParens(), scanner.spanFrom(start));
    }

    var condition = _supportsConditionInParens();
    whitespace();
    String? operator;
    while (lookingAtIdentifier()) {
      if (operator != null) {
        expectIdentifier(operator);
      } else if (scanIdentifier("or")) {
        operator = "or";
      } else {
        expectIdentifier("and");
        operator = "and";
      }

      whitespace();
      var right = _supportsConditionInParens();
      condition = SupportsOperation(
          condition, right, operator, scanner.spanFrom(start));
      whitespace();
    }
    return condition;
  }

  /// Consumes a parenthesized supports condition, or an interpolation.
  SupportsCondition _supportsConditionInParens() {
    var start = scanner.state;

    if (_lookingAtInterpolatedIdentifier()) {
      var identifier = interpolatedIdentifier();
      if (identifier.asPlain?.toLowerCase() == "not") {
        error('"not" is not a valid identifier here.', identifier.span);
      }

      if (scanner.scanChar($lparen)) {
        var arguments = _interpolatedDeclarationValue(
            allowEmpty: true, allowSemicolon: true);
        scanner.expectChar($rparen);
        return SupportsFunction(identifier, arguments, scanner.spanFrom(start));
      } else if (identifier.contents.length != 1 ||
          identifier.contents.first is! Expression) {
        error("Expected @supports condition.", identifier.span);
      } else {
        return SupportsInterpolation(
            identifier.contents.first as Expression, scanner.spanFrom(start));
      }
    }

    scanner.expectChar($lparen);
    whitespace();
    if (scanIdentifier("not")) {
      whitespace();
      var condition = _supportsConditionInParens();
      scanner.expectChar($rparen);
      return SupportsNegation(condition, scanner.spanFrom(start));
    } else if (scanner.peekChar() == $lparen) {
      var condition = _supportsCondition();
      scanner.expectChar($rparen);
      return condition;
    }

    // Unfortunately, we may have to backtrack here. The grammar is:
    //
    //       Expression ":" Expression
    //     | InterpolatedIdentifier InterpolatedAnyValue?
    //
    // These aren't ambiguous because this `InterpolatedAnyValue` is forbidden
    // from containing a top-level colon, but we still have to parse the full
    // expression to figure out if there's a colon after it.
    //
    // We could avoid the overhead of a full expression parse by looking ahead
    // for a colon (outside of balanced brackets), but in practice we expect the
    // vast majority of real uses to be `Expression ":" Expression`, so it makes
    // sense to parse that case faster in exchange for less code complexity and
    // a slower backtracking case.
    Expression name;
    var nameStart = scanner.state;
    var wasInParentheses = _inParentheses;
    try {
      name = _expression();
      scanner.expectChar($colon);
    } on FormatException catch (_) {
      scanner.state = nameStart;
      _inParentheses = wasInParentheses;

      var identifier = interpolatedIdentifier();
      var operation = _trySupportsOperation(identifier, nameStart);
      if (operation != null) {
        scanner.expectChar($rparen);
        return operation;
      }

      // If parsing an expression fails, try to parse an
      // `InterpolatedAnyValue` instead. But if that value runs into a
      // top-level colon, then this is probably intended to be a declaration
      // after all, so we rethrow the declaration-parsing error.
      var contents = (InterpolationBuffer()
            ..addInterpolation(identifier)
            ..addInterpolation(_interpolatedDeclarationValue(
                allowEmpty: true, allowSemicolon: true, allowColon: false)))
          .interpolation(scanner.spanFrom(nameStart));
      if (scanner.peekChar() == $colon) rethrow;

      scanner.expectChar($rparen);
      return SupportsAnything(contents, scanner.spanFrom(start));
    }

    var declaration = _supportsDeclarationValue(name, start);
    scanner.expectChar($rparen);
    return declaration;
  }

  /// Parses and returns the right-hand side of a declaration in a supports
  /// query.
  SupportsDeclaration _supportsDeclarationValue(
      Expression name, LineScannerState start) {
    Expression value;
    if (name is StringExpression &&
        !name.hasQuotes &&
        name.text.initialPlain.startsWith("--")) {
      value = StringExpression(_interpolatedDeclarationValue());
    } else {
      whitespace();
      value = _expression();
    }
    return SupportsDeclaration(name, value, scanner.spanFrom(start));
  }

  /// If [interpolation] is followed by `"and"` or `"or"`, parse it as a supports operation.
  ///
  /// Otherwise, return `null` without moving the scanner position.
  SupportsOperation? _trySupportsOperation(
      Interpolation interpolation, LineScannerState start) {
    if (interpolation.contents.length != 1) return null;
    var expression = interpolation.contents.first;
    if (expression is! Expression) return null;

    var beforeWhitespace = scanner.state;
    whitespace();

    SupportsOperation? operation;
    String? operator;
    while (lookingAtIdentifier()) {
      if (operator != null) {
        expectIdentifier(operator);
      } else if (scanIdentifier("and")) {
        operator = "and";
      } else if (scanIdentifier("or")) {
        operator = "or";
      } else {
        scanner.state = beforeWhitespace;
        return null;
      }

      whitespace();
      var right = _supportsConditionInParens();
      operation = SupportsOperation(
          operation ?? SupportsInterpolation(expression, interpolation.span),
          right,
          operator,
          scanner.spanFrom(start));
      whitespace();
    }

    return operation;
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
    if (second == $hash) return scanner.peekChar(2) == $lbrace;
    return isNameStart(second) || second == $backslash || second == $dash;
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

  /// Consumes a block of [child] statements and passes them, as well as the
  /// span from [start] to the end of the child block, to [create].
  T _withChildren<T>(Statement child(), LineScannerState start,
      T create(List<Statement> children, FileSpan span)) {
    var result = create(children(child), scanner.spanFrom(start));
    whitespaceWithoutComments();
    return result;
  }

  /// Consumes a string that contains a valid URL.
  Uri _urlString() {
    var start = scanner.state;
    var url = string();
    try {
      return Uri.parse(url);
    } on FormatException catch (innerError, stackTrace) {
      error("Invalid URL: ${innerError.message}", scanner.spanFrom(start),
          stackTrace);
    }
  }

  /// Like [identifier], but rejects identifiers that begin with `_` or `-`.
  String _publicIdentifier() {
    var start = scanner.state;
    var result = identifier(normalize: true);
    _assertPublic(result, () => scanner.spanFrom(start));
    return result;
  }

  /// Throws an error if [identifier] isn't public.
  ///
  /// Calls [span] to provide the span for an error if one occurs.
  void _assertPublic(String identifier, FileSpan span()) {
    if (!isPrivate(identifier)) return;
    error("Private members can't be accessed from outside their modules.",
        span());
  }

  // ## Abstract Methods

  /// Whether this is parsing the indented syntax.
  @protected
  bool get indented;

  /// Whether this is a plain CSS stylesheet.
  @protected
  bool get plainCss => false;

  /// The indentation level at the current scanner position.
  ///
  /// This value isn't used directly by [StylesheetParser]; it's just passed to
  /// [scanElse].
  @protected
  int get currentIndentation;

  /// Parses and returns a selector used in a style rule.
  @protected
  Interpolation styleRuleSelector();

  /// Asserts that the scanner is positioned before a statement separator, or at
  /// the end of a list of statements.
  ///
  /// If the [name] of the parent rule is passed, it's used for error reporting.
  ///
  /// This consumes whitespace, but nothing else, including comments.
  @protected
  void expectStatementSeparator([String? name]);

  /// Whether the scanner is positioned at the end of a statement.
  @protected
  bool atEndOfStatement();

  /// Whether the scanner is positioned before a block of children that can be
  /// parsed with [children].
  @protected
  bool lookingAtChildren();

  /// Tries to scan an `@else` rule after an `@if` block, and returns whether
  /// that succeeded.
  ///
  /// This should just scan the rule name, not anything afterwards.
  /// [ifIndentation] is the result of [currentIndentation] from before the
  /// corresponding `@if` was parsed.
  @protected
  bool scanElse(int ifIndentation);

  /// Consumes a block of child statements.
  ///
  /// Unlike most production consumers, this does *not* consume trailing
  /// whitespace. This is necessary to ensure that the source span for the
  /// parent rule doesn't cover whitespace after the rule.
  @protected
  List<Statement> children(Statement child());

  /// Consumes top-level statements.
  ///
  /// The [statement] callback may return `null`, indicating that a statement
  /// was consumed that shouldn't be added to the AST.
  @protected
  List<Statement> statements(Statement? statement());
}
