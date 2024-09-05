// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/sass.dart';
import '../color_names.dart';
import '../deprecation.dart';
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

  /// Whether the parser is currently within an expression.
  @protected
  bool get inExpression => _inExpression;
  var _inExpression = false;

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

  StylesheetParser(super.contents, {super.url, super.logger});

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
  (String name, ArgumentDeclaration) parseSignature(
      {bool requireParens = true}) {
    return wrapSpanFormatException(() {
      var name = identifier();
      var arguments = requireParens || scanner.peekChar() == $lparen
          ? _argumentDeclaration()
          : ArgumentDeclaration.empty(scanner.emptySpan);
      scanner.expectDone();
      return (name, arguments);
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

      case _:
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
      switch (identifier()) {
        case 'default':
          if (guarded) {
            logger.warnForDeprecation(
                Deprecation.duplicateVarFlags,
                '!default should only be written once for each variable.\n'
                'This will be an error in Dart Sass 2.0.0.',
                span: scanner.spanFrom(flagStart));
          }
          guarded = true;

        case 'global':
          if (namespace != null) {
            error("!global isn't allowed for variables in other modules.",
                scanner.spanFrom(flagStart));
          } else if (global) {
            logger.warnForDeprecation(
                Deprecation.duplicateVarFlags,
                '!global should only be written once for each variable.\n'
                'This will be an error in Dart Sass 2.0.0.',
                span: scanner.spanFrom(flagStart));
          }
          global = true;

        case _:
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
    return variableOrInterpolation is VariableDeclaration
        ? variableOrInterpolation
        : _styleRule(
            InterpolationBuffer()
              ..addInterpolation(variableOrInterpolation as Interpolation),
            start);
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

    var startsWithPunctuation = false;
    if (_lookingAtPotentialPropertyHack()) {
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
      var value = StringExpression(
          _interpolatedDeclarationValue(silentComments: false));
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
    if (_tryDeclarationChildren(name, start) case var nested?) return nested;

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

    if (_tryDeclarationChildren(name, start, value: value) case var nested?) {
      return nested;
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
    if (_lookingAtPotentialPropertyHack()) {
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
      var value = StringExpression(
          _interpolatedDeclarationValue(silentComments: false));
      expectStatementSeparator("custom property");
      return Declaration(name, value, scanner.spanFrom(start));
    }

    whitespace();
    if (_tryDeclarationChildren(name, start) case var nested?) return nested;

    var value = _expression();
    if (_tryDeclarationChildren(name, start, value: value) case var nested?) {
      return nested;
    } else {
      expectStatementSeparator();
      return Declaration(name, value, scanner.spanFrom(start));
    }
  }

  /// Tries parsing nested children of a declaration whose [name] has already
  /// been parsed, and returns `null` if it doesn't have any.
  ///
  /// If [value] is passed, it's used as the value of the property without
  /// nesting.
  Declaration? _tryDeclarationChildren(
      Interpolation name, LineScannerState start,
      {Expression? value}) {
    if (!lookingAtChildren()) return null;
    if (plainCss) {
      scanner.error("Nested declarations aren't allowed in plain CSS.");
    }
    return _withChildren(
        _declarationChild,
        start,
        (children, span) =>
            Declaration.nested(name, children, span, value: value));
  }

  /// Consumes a statement that's allowed within a declaration.
  Statement _declarationChild() => scanner.peekChar() == $at
      ? _declarationAtRule()
      : _propertyOrVariableDeclaration(parseCustomProperties: false);

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
    return switch (_plainAtRuleName()) {
      "content" => _contentRule(start),
      "debug" => _debugRule(start),
      "each" => _eachRule(start, _declarationChild),
      "else" => _disallowedAtRule(start),
      "error" => _errorRule(start),
      "for" => _forRule(start, _declarationChild),
      "if" => _ifRule(start, _declarationChild),
      "include" => _includeRule(start),
      "warn" => _warnRule(start),
      "while" => _whileRule(start, _declarationChild),
      _ => _disallowedAtRule(start)
    };
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
    return switch (_plainAtRuleName()) {
      "debug" => _debugRule(start),
      "each" => _eachRule(start, _functionChild),
      "else" => _disallowedAtRule(start),
      "error" => _errorRule(start),
      "for" => _forRule(start, _functionChild),
      "if" => _ifRule(start, _functionChild),
      "return" => _returnRule(start),
      "warn" => _warnRule(start),
      "while" => _whileRule(start, _functionChild),
      _ => _disallowedAtRule(start),
    };
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
    } else if (lookingAtChildren() || (indented && atEndOfStatement())) {
      return _withChildren(
          _statement, start, (children, span) => AtRootRule(children, span));
    } else {
      var child = _styleRule();
      return AtRootRule([child], scanner.spanFrom(start));
    }
  }

  /// Consumes a query expression of the form `(foo: bar)`.
  Interpolation _atRootQuery() {
    var start = scanner.state;
    var buffer = InterpolationBuffer();
    scanner.expectChar($lparen);
    buffer.writeCharCode($lparen);
    whitespace();

    _addOrInject(buffer, _expression());
    if (scanner.scanChar($colon)) {
      whitespace();
      buffer.writeCharCode($colon);
      buffer.writeCharCode($space);
      _addOrInject(buffer, _expression());
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

    var beforeWhitespace = scanner.location;
    whitespace();
    ArgumentInvocation arguments;
    if (scanner.peekChar() == $lparen) {
      arguments = _argumentInvocation(mixin: true);
      whitespace();
    } else {
      arguments = ArgumentInvocation.empty(beforeWhitespace.pointSpan());
    }

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
    if (optional) {
      expectIdentifier("optional");
      whitespace();
    }
    expectStatementSeparator("@extend rule");
    return ExtendRule(value, scanner.spanFrom(start), optional: optional);
  }

  /// Consumes a function declaration.
  ///
  /// [start] should point before the `@`.
  FunctionRule _functionRule(LineScannerState start) {
    var precedingComment = lastSilentComment;
    lastSilentComment = null;
    var beforeName = scanner.state;
    var name = identifier();

    if (name.startsWith('--')) {
      logger.warnForDeprecation(
          Deprecation.cssFunctionMixin,
          'Sass @function names beginning with -- are deprecated for forward-'
          'compatibility with plain CSS mixins.\n'
          '\n'
          'For details, see https://sass-lang.com/d/css-function-mixin',
          span: scanner.spanFrom(beforeName));
    }

    whitespace();
    var arguments = _argumentDeclaration();

    if (_inMixin || _inContentBlock) {
      error("Mixins may not contain function declarations.",
          scanner.spanFrom(start));
    } else if (_inControlDirective) {
      error("Functions may not be declared in control directives.",
          scanner.spanFrom(start));
    }

    if (unvendor(name)
        case "calc" ||
            "element" ||
            "expression" ||
            "url" ||
            "and" ||
            "or" ||
            "not" ||
            "clamp") {
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
      (shownMixinsAndFunctions, shownVariables) = _memberList();
    } else if (scanIdentifier("hide")) {
      (hiddenMixinsAndFunctions, hiddenVariables) = _memberList();
    }

    var configuration = _configuration(allowGuarded: true);
    whitespace();

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
  (Set<String>, Set<String>) _memberList() {
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

    return (identifiers, variables);
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
      if (argument is DynamicImport) {
        logger.warnForDeprecation(
            Deprecation.import,
            'Sass @import rules will be deprecated in the future.\n'
            'Remove the --future-deprecation=import flag to silence this '
            'warning for now.',
            span: argument.span);
      }
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
    if (scanner.peekChar() case $u || $U) {
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

    return switch (url.codeUnitAt(0)) {
      $slash => url.codeUnitAt(1) == $slash,
      $h => url.startsWith("http://") || url.startsWith("https://"),
      _ => false
    };
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
      if (_tryImportSupportsFunction() case var function?) return function;

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
    var beforeName = scanner.state;
    var name = identifier();

    if (name.startsWith('--')) {
      logger.warnForDeprecation(
          Deprecation.cssFunctionMixin,
          'Sass @mixin names beginning with -- are deprecated for forward-'
          'compatibility with plain CSS mixins.\n'
          '\n'
          'For details, see https://sass-lang.com/d/css-function-mixin',
          span: scanner.spanFrom(beforeName));
    }

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
          case "url" || "url-prefix" || "domain":
            if (_tryUrlContents(identifierStart, name: identifier)
                case var contents?) {
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

          case "regexp":
            buffer.write("regexp(");
            scanner.expectChar($lparen);
            buffer.addInterpolation(interpolatedString().asInterpolation());
            scanner.expectChar($rparen);
            buffer.writeCharCode($rparen);
            needsDeprecationWarning = true;

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
        logger.warnForDeprecation(
            Deprecation.mozDocument,
            "@-moz-document is deprecated and support will be removed in Dart "
            "Sass 2.0.0.\n"
            "\n"
            "For details, see https://sass-lang.com/d/moz-document.",
            span: span);
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
    whitespace();

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
        if (identifier() == 'default') {
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
    if (scanner.peekChar() != $exclamation && !atEndOfStatement()) {
      value = _interpolatedDeclarationValue(allowOpenBrace: false);
    }

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
    _interpolatedDeclarationValue(allowEmpty: true, allowOpenBrace: false);
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
    var wasInExpression = _inExpression;
    var wasInParentheses = _inParentheses;
    _inExpression = true;

    // We use the convention below of referring to nullable variables that are
    // shared across anonymous functions in this method with a trailing
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

        if (operator case BinaryOperator.plus || BinaryOperator.minus) {
          if (scanner.string.substring(
                      right.span.start.offset - 1, right.span.start.offset) ==
                  operator.operator &&
              scanner.string.codeUnitAt(left.span.end.offset).isWhitespace) {
            logger.warnForDeprecation(
                Deprecation.strictUnary,
                "This operation is parsed as:\n"
                "\n"
                "    $left ${operator.operator} $right\n"
                "\n"
                "but you may have intended it to mean:\n"
                "\n"
                "    $left (${operator.operator}$right)\n"
                "\n"
                "Add a space after ${operator.operator} to clarify that it's "
                "meant to be a binary operation, or wrap\n"
                "it in parentheses to make it a unary operation. This will be "
                "an error in future\n"
                "versions of Sass.\n"
                "\n"
                "More info and automated migrator: "
                "https://sass-lang.com/d/strict-unary",
                span: singleExpression_!.span);
          }
        }
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
          operator != BinaryOperator.singleEquals &&
          // These are allowed in calculations, so we have to check them at
          // evaluation time.
          operator != BinaryOperator.plus &&
          operator != BinaryOperator.minus &&
          operator != BinaryOperator.times &&
          operator != BinaryOperator.dividedBy) {
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
      if (spaceExpressions == null) return;

      var singleExpression = singleExpression_;
      if (singleExpression == null) scanner.error("Expected expression.");

      spaceExpressions.add(singleExpression);
      singleExpression_ = ListExpression(spaceExpressions, ListSeparator.space,
          spaceExpressions.first.span.expand(singleExpression.span));
      spaceExpressions_ = null;
    }

    loop:
    while (true) {
      whitespace();
      if (until != null && until()) break;

      switch (scanner.peekChar()) {
        case null:
          break loop;

        case $lparen:
          // Parenthesized numbers can't be slash-separated.
          addSingleExpression(parentheses());

        case $lbracket:
          addSingleExpression(_expression(bracketList: true));

        case $dollar:
          addSingleExpression(_variable());

        case $ampersand:
          addSingleExpression(_selector());

        case $single_quote || $double_quote:
          addSingleExpression(interpolatedString());

        case $hash:
          addSingleExpression(_hashExpression());

        case $equal:
          scanner.readChar();
          if (singleEquals && scanner.peekChar() != $equal) {
            addOperator(BinaryOperator.singleEquals);
          } else {
            scanner.expectChar($equal);
            addOperator(BinaryOperator.equals);
          }

        case $exclamation:
          switch (scanner.peekChar(1)) {
            case $equal:
              scanner.readChar();
              scanner.readChar();
              addOperator(BinaryOperator.notEquals);
            case null || $i || $I || int(isWhitespace: true):
              addSingleExpression(_importantExpression());
            case _:
              break loop;
          }

        case $langle:
          scanner.readChar();
          addOperator(scanner.scanChar($equal)
              ? BinaryOperator.lessThanOrEquals
              : BinaryOperator.lessThan);

        case $rangle:
          scanner.readChar();
          addOperator(scanner.scanChar($equal)
              ? BinaryOperator.greaterThanOrEquals
              : BinaryOperator.greaterThan);

        case $asterisk:
          scanner.readChar();
          addOperator(BinaryOperator.times);

        case $plus when singleExpression_ == null:
          addSingleExpression(_unaryOperation());

        case $plus:
          scanner.readChar();
          addOperator(BinaryOperator.plus);

        case $minus:
          if (scanner.peekChar(1) case int(isDigit: true) || $dot
              // Make sure `1-2` parses as `1 - 2`, not `1 (-2)`.
              when singleExpression_ == null ||
                  scanner.peekChar(-1).isWhitespace) {
            addSingleExpression(_number());
          } else if (_lookingAtInterpolatedIdentifier()) {
            addSingleExpression(identifierLike());
          } else if (singleExpression_ == null) {
            addSingleExpression(_unaryOperation());
          } else {
            scanner.readChar();
            addOperator(BinaryOperator.minus);
          }

        case $slash when singleExpression_ == null:
          addSingleExpression(_unaryOperation());

        case $slash:
          scanner.readChar();
          addOperator(BinaryOperator.dividedBy);

        case $percent:
          scanner.readChar();
          addOperator(BinaryOperator.modulo);

        // dart-lang/sdk#52740
        // ignore: non_constant_relational_pattern_expression
        case >= $0 && <= $9:
          addSingleExpression(_number());

        case $dot when scanner.peekChar(1) == $dot:
          break loop;

        case $dot:
          addSingleExpression(_number());

        case $a when !plainCss && scanIdentifier("and"):
          addOperator(BinaryOperator.and);

        case $o when !plainCss && scanIdentifier("or"):
          addOperator(BinaryOperator.or);

        // dart-lang/sdk#52740
        // ignore: non_constant_relational_pattern_expression
        case $u || $U when scanner.peekChar(1) == $plus:
          addSingleExpression(_unicodeRange());

        // ignore: non_constant_relational_pattern_expression
        case (>= $a && <= $z) ||
              // ignore: non_constant_relational_pattern_expression
              (>= $A && <= $Z) ||
              $_ ||
              $backslash ||
              >= 0x80:
          addSingleExpression(identifierLike());

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

        case _:
          break loop;
      }
    }

    if (bracketList) scanner.expectChar($rbracket);

    // TODO(dart-lang/sdk#52756): Use patterns to null-check these values.
    var commaExpressions = commaExpressions_;
    var spaceExpressions = spaceExpressions_;
    if (commaExpressions != null) {
      resolveSpaceExpressions();
      _inParentheses = wasInParentheses;
      var singleExpression = singleExpression_;
      if (singleExpression != null) commaExpressions.add(singleExpression);
      _inExpression = wasInExpression;
      return ListExpression(commaExpressions, ListSeparator.comma,
          scanner.spanFrom(beforeBracket ?? start),
          brackets: bracketList);
    } else if (bracketList && spaceExpressions != null) {
      resolveOperations();
      _inExpression = wasInExpression;
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
      _inExpression = wasInExpression;
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
      expression is FunctionExpression ||
      (expression is BinaryOperationExpression && expression.allowsSlash);

  /// Consumes an expression that doesn't contain any top-level whitespace.
  Expression _singleExpression() => switch (scanner.peekChar()) {
        // Note: when adding a new case, make sure it's reflected in
        // [_lookingAtExpression] and [_expression].
        null => scanner.error("Expected expression."),
        $lparen => parentheses(),
        $slash => _unaryOperation(),
        $dot => _number(),
        $lbracket => _expression(bracketList: true),
        $dollar => _variable(),
        $ampersand => _selector(),
        $single_quote || $double_quote => interpolatedString(),
        $hash => _hashExpression(),
        $plus => _plusExpression(),
        $minus => _minusExpression(),
        $exclamation => _importantExpression(),
        // dart-lang/sdk#52740
        // ignore: non_constant_relational_pattern_expression
        $u || $U when scanner.peekChar(1) == $plus => _unicodeRange(),
        // ignore: non_constant_relational_pattern_expression
        >= $0 && <= $9 => _number(),
        // ignore: non_constant_relational_pattern_expression
        (>= $a && <= $z) ||
        // ignore: non_constant_relational_pattern_expression
        (>= $A && <= $Z) ||
        $_ ||
        $backslash ||
        >= 0x80 =>
          identifierLike(),
        _ => scanner.error("Expected expression.")
      };

  /// Consumes a parenthesized expression.
  @protected
  Expression parentheses() {
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
    var pairs = [(first, expressionUntilComma())];

    while (scanner.scanChar($comma)) {
      whitespace();
      if (!_lookingAtExpression()) break;

      var key = expressionUntilComma();
      scanner.expectChar($colon);
      whitespace();
      var value = expressionUntilComma();
      pairs.add((key, value));
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

    if (scanner.peekChar()?.isDigit ?? false) {
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
    double? alpha;
    if (!scanner.peekChar().isHex) {
      // #abc
      red = (digit1 << 4) + digit1;
      green = (digit2 << 4) + digit2;
      blue = (digit3 << 4) + digit3;
    } else {
      var digit4 = _hexDigit();
      if (!scanner.peekChar().isHex) {
        // #abcd
        red = (digit1 << 4) + digit1;
        green = (digit2 << 4) + digit2;
        blue = (digit3 << 4) + digit3;
        alpha = ((digit4 << 4) + digit4) / 0xff;
      } else {
        red = (digit1 << 4) + digit2;
        green = (digit3 << 4) + digit4;
        blue = (_hexDigit() << 4) + _hexDigit();

        if (scanner.peekChar().isHex) {
          alpha = ((_hexDigit() << 4) + _hexDigit()) / 0xff;
        }
      }
    }

    return SassColor.rgbInternal(
        red,
        green,
        blue,
        alpha ?? 1,
        // Don't emit four- or eight-digit hex colors as hex, since that's not
        // yet well-supported in browsers.
        alpha == null ? SpanColorFormat(scanner.spanFrom(start)) : null);
  }

  /// Returns whether [interpolation] is a plain string that can be parsed as a
  /// hex color.
  bool _isHexColor(Interpolation interpolation) {
    var plain = interpolation.asPlain;
    if (plain case String(length: 3 || 4 || 6 || 8)) {
      return plain.codeUnits.every((char) => char.isHex);
    } else {
      return false;
    }
  }

  // Consumes a single hexadecimal digit.
  int _hexDigit() => (scanner.peekChar()?.isHex ?? false)
      ? asHex(scanner.readChar())
      : scanner.error("Expected hex digit.");

  /// Consumes an expression that starts with a `+`.
  Expression _plusExpression() {
    assert(scanner.peekChar() == $plus);
    var next = scanner.peekChar(1);
    return next.isDigit || next == $dot ? _number() : _unaryOperation();
  }

  /// Consumes an expression that starts with a `-`.
  Expression _minusExpression() {
    assert(scanner.peekChar() == $minus);
    if (scanner.peekChar(1) case int(isDigit: true) || $dot) return _number();
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
  UnaryOperator? _unaryOperatorFor(int character) => switch (character) {
        $plus => UnaryOperator.plus,
        $minus => UnaryOperator.minus,
        $slash => UnaryOperator.divide,
        _ => null
      };

  /// Consumes a number expression.
  NumberExpression _number() {
    var start = scanner.state;
    var first = scanner.peekChar();
    if (first == $plus || first == $minus) scanner.readChar();

    if (scanner.peekChar() != $dot) _consumeNaturalNumber();

    // Don't complain about a dot after a number unless the number starts with a
    // dot. We don't allow a plain ".", but we need to allow "1." so that
    // "1..." will work as a rest argument.
    _tryDecimal(
        allowTrailingDot: scanner.position != start.position &&
            first != $plus &&
            first != $minus);
    _tryExponent();

    // Use Dart's built-in double parsing so that we don't accumulate
    // floating-point errors for numbers with lots of digits.
    var number = double.parse(scanner.substring(start.position));

    String? unit;
    if (scanner.scanChar($percent)) {
      unit = "%";
    } else if (lookingAtIdentifier() &&
        // Disallow units beginning with `--`.
        (scanner.peekChar() != $dash || scanner.peekChar(1) != $dash)) {
      unit = identifier(unit: true);
    }

    return NumberExpression(number, scanner.spanFrom(start), unit: unit);
  }

  /// Consumes a natural number (that is, a non-negative integer).
  ///
  /// Doesn't support scientific notation.
  void _consumeNaturalNumber() {
    if (!scanner.readChar().isDigit) {
      scanner.error("Expected digit.", position: scanner.position - 1);
    }

    while (scanner.peekChar().isDigit) {
      scanner.readChar();
    }
  }

  /// Consumes the decimal component of a number if it exists.
  ///
  /// If [allowTrailingDot] is `false`, this will throw an error if there's a
  /// dot without any numbers following it. Otherwise, it will ignore the dot
  /// without consuming it.
  void _tryDecimal({bool allowTrailingDot = false}) {
    if (scanner.peekChar() != $dot) return;

    if (!scanner.peekChar(1).isDigit) {
      if (allowTrailingDot) return;
      scanner.error("Expected digit.", position: scanner.position + 1);
    }

    scanner.readChar();
    while (scanner.peekChar().isDigit) {
      scanner.readChar();
    }
  }

  /// Consumes the exponent component of a number if it exists.
  void _tryExponent() {
    var first = scanner.peekChar();
    if (first != $e && first != $E) return;

    var next = scanner.peekChar(1);
    if (!next.isDigit && next != $minus && next != $plus) return;

    scanner.readChar();
    if (next case $plus || $minus) scanner.readChar();
    if (!scanner.peekChar().isDigit) scanner.error("Expected digit.");

    while (scanner.peekChar().isDigit) {
      scanner.readChar();
    }
  }

  /// Consumes a unicode range expression.
  StringExpression _unicodeRange() {
    var start = scanner.state;
    expectIdentChar($u);
    scanner.expectChar($plus);

    var firstRangeLength = 0;
    while (scanCharIf((char) => char != null && char.isHex)) {
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
      while (scanCharIf((char) => char != null && char.isHex)) {
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
    // NOTE: this logic is largely duplicated in Parser.string. Most changes
    // here should be mirrored there.

    var start = scanner.state;
    var quote = scanner.readChar();

    if (quote != $single_quote && quote != $double_quote) {
      scanner.error("Expected string.", position: start.position);
    }

    var buffer = InterpolationBuffer();
    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case var next when next == quote:
          scanner.readChar();
          break loop;
        case null || int(isNewline: true):
          scanner.error("Expected ${String.fromCharCode(quote)}.");
        case $backslash:
          var second = scanner.peekChar(1);
          if (second.isNewline) {
            scanner.readChar();
            scanner.readChar();
            if (second == $cr) scanner.scanChar($lf);
          } else {
            buffer.writeCharCode(escapeCharacter());
          }
        case $hash when scanner.peekChar(1) == $lbrace:
          buffer.add(singleInterpolation());
        case _:
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
        var expression = _singleExpression();
        return UnaryOperationExpression(UnaryOperator.not, expression,
            identifier.span.expand(expression.span));
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

        if (colorsByName[lower] case var color?) {
          color = SassColor.rgbInternal(color.red, color.green, color.blue,
              color.alpha, SpanColorFormat(identifier.span));
          return ColorExpression(color, identifier.span);
        }
      }

      if (trySpecialFunction(lower, start) case var specialFunction?) {
        return specialFunction;
      }
    }

    switch (scanner.peekChar()) {
      case $dot when scanner.peekChar(1) == $dot:
        return StringExpression(identifier);

      case $dot:
        scanner.readChar();
        // TODO(dart-lang/sdk#52757): Make this a separate case.
        if (plain != null) return namespacedExpression(plain, start);
        error("Interpolation isn't allowed in namespaces.", identifier.span);

      case $lparen when plain != null:
        return FunctionExpression(
            plain,
            _argumentInvocation(allowEmptySecondArg: lower == 'var'),
            scanner.spanFrom(start));

      case $lparen:
        return InterpolatedFunctionExpression(
            identifier, _argumentInvocation(), scanner.spanFrom(start));

      case _:
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
    var normalized = unvendor(name);

    InterpolationBuffer buffer;
    switch (normalized) {
      case "calc" when normalized != name && scanner.scanChar($lparen):
      case "element" || "expression" when scanner.scanChar($lparen):
        buffer = InterpolationBuffer()
          ..write(name)
          ..writeCharCode($lparen);

      case "progid" when scanner.scanChar($colon):
        buffer = InterpolationBuffer()
          ..write(name)
          ..writeCharCode($colon);
        var next = scanner.peekChar();
        while (next != null && (next.isAlphabetic || next == $dot)) {
          buffer.writeCharCode(scanner.readChar());
          next = scanner.peekChar();
        }
        scanner.expectChar($lparen);
        buffer.writeCharCode($lparen);

      case "url":
        return _tryUrlContents(start)
            .andThen((contents) => StringExpression(contents));

      case _:
        return null;
    }

    buffer.addInterpolation(_interpolatedDeclarationValue(allowEmpty: true));
    scanner.expectChar($rparen);
    buffer.writeCharCode($rparen);

    return StringExpression(buffer.interpolation(scanner.spanFrom(start)));
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
    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case null:
          break loop;
        case $backslash:
          buffer.write(escape());
        case $hash when scanner.peekChar(1) == $lbrace:
          buffer.add(singleInterpolation());
        case $exclamation ||
              $percent ||
              $ampersand ||
              $hash ||
              // dart-lang/sdk#52740
              // ignore: non_constant_relational_pattern_expression
              (>= $asterisk && <= $tilde) ||
              >= 0x80:
          buffer.writeCharCode(scanner.readChar());
        case int(isWhitespace: true):
          whitespaceWithoutComments();
          if (scanner.peekChar() != $rparen) break loop;
        case $rparen:
          buffer.writeCharCode(scanner.readChar());
          return buffer.interpolation(scanner.spanFrom(start));
        case _:
          break loop;
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
    if (_tryUrlContents(start) case var contents?) {
      return StringExpression(contents);
    }

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
  /// * This always stops at curly braces.
  ///
  /// * This does not interpret backslashes, since the text is expected to be
  ///   re-parsed.
  ///
  /// * This does not compress adjacent whitespace characters.
  @protected
  Interpolation almostAnyValue({bool omitComments = false}) {
    var start = scanner.state;
    var buffer = InterpolationBuffer();

    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case $backslash:
          // Write a literal backslash because this text will be re-parsed.
          buffer.writeCharCode(scanner.readChar());
          buffer.writeCharCode(scanner.readChar());

        case $double_quote || $single_quote:
          buffer.addInterpolation(interpolatedString().asInterpolation());

        case $slash:
          switch (scanner.peekChar(1)) {
            case $asterisk when !omitComments:
              buffer.write(rawText(loudComment));

            case $asterisk:
              loudComment();

            case $slash when !omitComments:
              buffer.write(rawText(silentComment));

            case $slash:
              silentComment();

            case _:
              buffer.writeCharCode(scanner.readChar());
          }

        case $hash when scanner.peekChar(1) == $lbrace:
          // Add a full interpolated identifier to handle cases like
          // "#{...}--1", since "--1" isn't a valid identifier on its own.
          buffer.addInterpolation(interpolatedIdentifier());

        case $cr || $lf || $ff:
          if (indented) break loop;
          buffer.writeCharCode(scanner.readChar());

        case $exclamation || $semicolon || $lbrace || $rbrace:
          break loop;

        case $u || $U:
          var beforeUrl = scanner.state;
          var identifier = this.identifier();
          if (identifier != "url" &&
              // This isn't actually a standard CSS feature, but it was
              // supported by the old `@document` rule so we continue to support
              // it for backwards-compatibility.
              identifier != "url-prefix") {
            buffer.write(identifier);
            continue loop;
          }

          if (_tryUrlContents(beforeUrl, name: identifier) case var contents?) {
            buffer.addInterpolation(contents);
          } else {
            scanner.state = beforeUrl;
            buffer.writeCharCode(scanner.readChar());
          }

        case null:
          break loop;

        case _ when lookingAtIdentifier():
          buffer.write(identifier());

        case _:
          buffer.writeCharCode(scanner.readChar());
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
  /// If [allowOpenBrace] is `false`, this stops at opening curly braces.
  ///
  /// If [silentComments] is `true`, this will parse silent comments as
  /// comments. Otherwise, it will preserve two adjacent slashes and emit them
  /// to CSS.
  ///
  /// Unlike [declarationValue], this allows interpolation.
  Interpolation _interpolatedDeclarationValue(
      {bool allowEmpty = false,
      bool allowSemicolon = false,
      bool allowColon = true,
      bool allowOpenBrace = true,
      bool silentComments = true}) {
    // NOTE: this logic is largely duplicated in Parser.declarationValue. Most
    // changes here should be mirrored there.

    var start = scanner.state;
    var buffer = InterpolationBuffer();

    var brackets = <int>[];
    var wroteNewline = false;
    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case $backslash:
          buffer.write(escape(identifierStart: true));
          wroteNewline = false;

        case $double_quote || $single_quote:
          buffer.addInterpolation(interpolatedString().asInterpolation());
          wroteNewline = false;

        case $slash:
          switch (scanner.peekChar(1)) {
            case $asterisk:
              buffer.write(rawText(loudComment));
              wroteNewline = false;

            case $slash when silentComments:
              silentComment();
              wroteNewline = false;

            case _:
              buffer.writeCharCode(scanner.readChar());
              wroteNewline = false;
          }

        // Add a full interpolated identifier to handle cases like "#{...}--1",
        // since "--1" isn't a valid identifier on its own.
        case $hash when scanner.peekChar(1) == $lbrace:
          buffer.addInterpolation(interpolatedIdentifier());
          wroteNewline = false;

        case $space || $tab
            when !wroteNewline && scanner.peekChar(1).isWhitespace:
          // Collapse whitespace into a single character unless it's following a
          // newline, in which case we assume it's indentation.
          scanner.readChar();

        case $space || $tab:
          buffer.writeCharCode(scanner.readChar());

        case $lf || $cr || $ff when indented:
          break loop;

        case $lf || $cr || $ff:
          // Collapse multiple newlines into one.
          if (!scanner.peekChar(-1).isNewline) buffer.writeln();
          scanner.readChar();
          wroteNewline = true;

        case $lbrace when !allowOpenBrace:
          break loop;

        case $lparen || $lbrace || $lbracket:
          var bracket = scanner.readChar();
          buffer.writeCharCode(bracket);
          brackets.add(opposite(bracket));
          wroteNewline = false;

        case $rparen || $rbrace || $rbracket:
          if (brackets.isEmpty) break loop;
          var bracket = brackets.removeLast();
          scanner.expectChar(bracket);
          buffer.writeCharCode(bracket);
          wroteNewline = false;

        case $semicolon:
          if (!allowSemicolon && brackets.isEmpty) break loop;
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;

        case $colon:
          if (!allowColon && brackets.isEmpty) break loop;
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;

        case $u || $U:
          var beforeUrl = scanner.state;
          var identifier = this.identifier();
          if (identifier != "url" &&
              // This isn't actually a standard CSS feature, but it was
              // supported by the old `@document` rule so we continue to support
              // it for backwards-compatibility.
              identifier != "url-prefix") {
            buffer.write(identifier);
            wroteNewline = false;
            continue loop;
          }

          if (_tryUrlContents(beforeUrl, name: identifier) case var contents?) {
            buffer.addInterpolation(contents);
          } else {
            scanner.state = beforeUrl;
            buffer.writeCharCode(scanner.readChar());
          }
          wroteNewline = false;

        case null:
          break loop;

        case _ when lookingAtIdentifier():
          buffer.write(identifier());
          wroteNewline = false;

        case _:
          buffer.writeCharCode(scanner.readChar());
          wroteNewline = false;
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

    switch (scanner.peekChar()) {
      case null:
        scanner.error("Expected identifier.");
      case int(isNameStart: true):
        buffer.writeCharCode(scanner.readChar());
      case $backslash:
        buffer.write(escape(identifierStart: true));
      case $hash when scanner.peekChar(1) == $lbrace:
        buffer.add(singleInterpolation());
      case _:
        scanner.error("Expected identifier.");
    }

    _interpolatedIdentifierBody(buffer);
    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes a chunk of a possibly-interpolated CSS identifier after the name
  /// start, and adds the contents to the [buffer] buffer.
  void _interpolatedIdentifierBody(InterpolationBuffer buffer) {
    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case null:
          break loop;
        case $underscore || $dash || int(isAlphanumeric: true) || >= 0x80:
          buffer.writeCharCode(scanner.readChar());
        case $backslash:
          buffer.write(escape());
        case $hash when scanner.peekChar(1) == $lbrace:
          buffer.add(singleInterpolation());
        case _:
          break loop;
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
      whitespace();
      if (!scanner.scanChar($comma)) break;
      buffer.writeCharCode($comma);
      buffer.writeCharCode($space);
    }
    return buffer.interpolation(scanner.spanFrom(start));
  }

  /// Consumes a single media query.
  void _mediaQuery(InterpolationBuffer buffer) {
    // This is somewhat duplicated in MediaQueryParser._mediaQuery.
    if (scanner.peekChar() == $lparen) {
      _mediaInParens(buffer);
      whitespace();
      if (scanIdentifier("and")) {
        buffer.write(" and ");
        expectWhitespace();
        _mediaLogicSequence(buffer, "and");
      } else if (scanIdentifier("or")) {
        buffer.write(" or ");
        expectWhitespace();
        _mediaLogicSequence(buffer, "or");
      }

      return;
    }

    var identifier1 = interpolatedIdentifier();
    if (equalsIgnoreCase(identifier1.asPlain, "not")) {
      // For example, "@media not (...) {"
      expectWhitespace();

      if (!_lookingAtInterpolatedIdentifier()) {
        buffer.write("not ");
        _mediaOrInterp(buffer);
        return;
      }
    }

    whitespace();
    buffer.addInterpolation(identifier1);
    if (!_lookingAtInterpolatedIdentifier()) {
      // For example, "@media screen {".
      return;
    }

    buffer.writeCharCode($space);
    var identifier2 = interpolatedIdentifier();

    if (equalsIgnoreCase(identifier2.asPlain, "and")) {
      expectWhitespace();
      // For example, "@media screen and ..."
      buffer.write(" and ");
    } else {
      whitespace();
      buffer.addInterpolation(identifier2);
      if (scanIdentifier("and")) {
        // For example, "@media only screen and ..."
        expectWhitespace();
        buffer.write(" and ");
      } else {
        // For example, "@media only screen {"
        return;
      }
    }

    // We've consumed either `IDENTIFIER "and"` or
    // `IDENTIFIER IDENTIFIER "and"`.

    if (scanIdentifier("not")) {
      // For example, "@media screen and not (...) {"
      expectWhitespace();
      buffer.write("not ");
      _mediaOrInterp(buffer);
      return;
    }

    _mediaLogicSequence(buffer, "and");
    return;
  }

  /// Consumes one or more `MediaOrInterp` expressions separated by [operator]
  /// and writes them to [buffer].
  void _mediaLogicSequence(InterpolationBuffer buffer, String operator) {
    while (true) {
      _mediaOrInterp(buffer);
      whitespace();

      if (!scanIdentifier(operator)) return;
      expectWhitespace();

      buffer.writeCharCode($space);
      buffer.write(operator);
      buffer.writeCharCode($space);
    }
  }

  /// Consumes a `MediaOrInterp` expression and writes it to [buffer].
  void _mediaOrInterp(InterpolationBuffer buffer) {
    if (scanner.peekChar() == $hash) {
      var interpolation = singleInterpolation();
      buffer
          .addInterpolation(Interpolation([interpolation], interpolation.span));
    } else {
      _mediaInParens(buffer);
    }
  }

  /// Consumes a `MediaInParens` expression and writes it to [buffer].
  void _mediaInParens(InterpolationBuffer buffer) {
    scanner.expectChar($lparen, name: "media condition in parentheses");
    buffer.writeCharCode($lparen);
    whitespace();

    if (scanner.peekChar() == $lparen) {
      _mediaInParens(buffer);
      whitespace();
      if (scanIdentifier("and")) {
        buffer.write(" and ");
        expectWhitespace();
        _mediaLogicSequence(buffer, "and");
      } else if (scanIdentifier("or")) {
        buffer.write(" or ");
        expectWhitespace();
        _mediaLogicSequence(buffer, "or");
      }
    } else if (scanIdentifier("not")) {
      buffer.write("not ");
      expectWhitespace();
      _mediaOrInterp(buffer);
    } else {
      buffer.add(_expressionUntilComparison());
      if (scanner.scanChar($colon)) {
        whitespace();
        buffer.writeCharCode($colon);
        buffer.writeCharCode($space);
        buffer.add(_expression());
      } else {
        var next = scanner.peekChar();
        if (next case $langle || $rangle || $equal) {
          buffer.writeCharCode($space);
          buffer.writeCharCode(scanner.readChar());
          if (next case $langle || $rangle when scanner.scanChar($equal)) {
            buffer.writeCharCode($equal);
          }
          buffer.writeCharCode($space);

          whitespace();
          buffer.add(_expressionUntilComparison());

          // dart-lang/sdk#45356
          if (next case $langle || $rangle when scanner.scanChar(next!)) {
            buffer.writeCharCode($space);
            buffer.writeCharCode(next);
            if (scanner.scanChar($equal)) buffer.writeCharCode($equal);
            buffer.writeCharCode($space);

            whitespace();
            buffer.add(_expressionUntilComparison());
          }
        }
      }
    }

    scanner.expectChar($rparen);
    whitespace();
    buffer.writeCharCode($rparen);
  }

  /// Consumes an expression until it reaches a top-level `<`, `>`, or a `=`
  /// that's not `==`.
  Expression _expressionUntilComparison() => _expression(
      until: () => switch (scanner.peekChar()) {
            $equal => scanner.peekChar(1) != $equal,
            $langle || $rangle => true,
            _ => false
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
      } else if (identifier.contents case [Expression expression]) {
        return SupportsInterpolation(expression, scanner.spanFrom(start));
      } else {
        error("Expected @supports condition.", identifier.span);
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
      if (_trySupportsOperation(identifier, nameStart) case var operation?) {
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
    if (name case StringExpression(hasQuotes: false, :var text)
        when text.initialPlain.startsWith("--")) {
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
  bool _lookingAtInterpolatedIdentifier() =>
      // See also [ScssParser._lookingAtIdentifier].

      switch (scanner.peekChar()) {
        null => false,
        int(isNameStart: true) || $backslash => true,
        $hash => scanner.peekChar(1) == $lbrace,
        $dash => switch (scanner.peekChar(1)) {
            null => false,
            $hash => scanner.peekChar(2) == $lbrace,
            int(isNameStart: true) || $backslash || $dash => true,
            _ => false
          },
        _ => false
      };

  /// Returns whether the scanner is immediately before a character that could
  /// start a `*prop: val`, `:prop: val`, `#prop: val`, or `.prop: val` hack.
  bool _lookingAtPotentialPropertyHack() => switch (scanner.peekChar()) {
        $colon || $asterisk || $dot => true,
        $hash => scanner.peekChar(1) != $lbrace,
        _ => false
      };

  /// Returns whether the scanner is immediately before a sequence of characters
  /// that could be part of an CSS identifier body.
  ///
  /// The identifier body may include interpolation.
  bool _lookingAtInterpolatedIdentifierBody() => switch (scanner.peekChar()) {
        null => false,
        int(isName: true) || $backslash => true,
        $hash => scanner.peekChar(1) == $lbrace,
        _ => false
      };

  /// Returns whether the scanner is immediately before a SassScript expression.
  bool _lookingAtExpression() => switch (scanner.peekChar()) {
        null => false,
        $dot => scanner.peekChar(1) != $dot,
        $exclamation => switch (scanner.peekChar(1)) {
            null || $i || $I || int(isWhitespace: true) => true,
            _ => false
          },
        $lparen ||
        $slash ||
        $lbracket ||
        $single_quote ||
        $double_quote ||
        $hash ||
        $plus ||
        $minus ||
        $backslash ||
        $dollar ||
        $ampersand ||
        int(isNameStart: true) ||
        int(isDigit: true) =>
          true,
        _ => false
      };

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
    var result = identifier();
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

  /// Adds [expression] to [buffer], or if it's an unquoted string adds the
  /// interpolation it contains instead.
  void _addOrInject(InterpolationBuffer buffer, Expression expression) {
    if (expression is StringExpression && !expression.hasQuotes) {
      buffer.addInterpolation(expression.text);
    } else {
      buffer.add(expression);
    }
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
