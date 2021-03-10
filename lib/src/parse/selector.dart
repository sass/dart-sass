// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/selector.dart';
import '../logger.dart';
import '../util/character.dart';
import '../utils.dart';
import 'parser.dart';

/// Pseudo-class selectors that take unadorned selectors as arguments.
final _selectorPseudoClasses = {
  "not",
  "matches",
  "current",
  "any",
  "has",
  "host",
  "host-context"
};

/// Pseudo-element selectors that take unadorned selectors as arguments.
final _selectorPseudoElements = {"slotted"};

/// A parser for selectors.
class SelectorParser extends Parser {
  /// Whether this parser allows the parent selector `&`.
  final bool _allowParent;

  /// Whether this parser allows placeholder selectors beginning with `%`.
  final bool _allowPlaceholder;

  SelectorParser(String contents,
      {Object url,
      Logger logger,
      bool allowParent = true,
      bool allowPlaceholder = true})
      : _allowParent = allowParent,
        _allowPlaceholder = allowPlaceholder,
        super(contents, url: url, logger: logger);

  SelectorList parse() {
    return wrapSpanFormatException(() {
      var selector = _selectorList();
      if (!scanner.isDone) scanner.error("expected selector.");
      return selector;
    });
  }

  CompoundSelector parseCompoundSelector() {
    return wrapSpanFormatException(() {
      var compound = _compoundSelector();
      if (!scanner.isDone) scanner.error("expected selector.");
      return compound;
    });
  }

  SimpleSelector parseSimpleSelector() {
    return wrapSpanFormatException(() {
      var simple = _simpleSelector();
      if (!scanner.isDone) scanner.error("unexpected token.");
      return simple;
    });
  }

  /// Consumes a selector list.
  SelectorList _selectorList() {
    var previousLine = scanner.line;
    var components = <ComplexSelector>[_complexSelector()];

    whitespace();
    while (scanner.scanChar($comma)) {
      whitespace();
      var next = scanner.peekChar();
      if (next == $comma) continue;
      if (scanner.isDone) break;

      var lineBreak = scanner.line != previousLine;
      if (lineBreak) previousLine = scanner.line;
      components.add(_complexSelector(lineBreak: lineBreak));
    }

    return SelectorList(components);
  }

  /// Consumes a complex selector.
  ///
  /// If [lineBreak] is `true`, that indicates that there was a line break
  /// before this selector.
  ComplexSelector _complexSelector({bool lineBreak = false}) {
    var components = <ComplexSelectorComponent>[];

    loop:
    while (true) {
      whitespace();

      var next = scanner.peekChar();
      switch (next) {
        case $plus:
          scanner.readChar();
          components.add(Combinator.nextSibling);
          break;

        case $gt:
          scanner.readChar();
          components.add(Combinator.child);
          break;

        case $tilde:
          scanner.readChar();
          components.add(Combinator.followingSibling);
          break;

        case $lbracket:
        case $dot:
        case $hash:
        case $percent:
        case $colon:
        case $ampersand:
        case $asterisk:
        case $pipe:
          components.add(_compoundSelector());
          if (scanner.peekChar() == $ampersand) {
            scanner.error(
                '"&" may only used at the beginning of a compound selector.');
          }
          break;

        default:
          if (next == null || !lookingAtIdentifier()) break loop;
          components.add(_compoundSelector());
          if (scanner.peekChar() == $ampersand) {
            scanner.error(
                '"&" may only used at the beginning of a compound selector.');
          }
          break;
      }
    }

    if (components.isEmpty) scanner.error("expected selector.");
    return ComplexSelector(components, lineBreak: lineBreak);
  }

  /// Consumes a compound selector.
  CompoundSelector _compoundSelector() {
    var components = <SimpleSelector>[_simpleSelector()];

    while (isSimpleSelectorStart(scanner.peekChar())) {
      components.add(_simpleSelector(allowParent: false));
    }

    return CompoundSelector(components);
  }

  /// Consumes a simple selector.
  ///
  /// If [allowParent] is passed, it controls whether the parent selector `&` is
  /// allowed. Otherwise, it defaults to [_allowParent].
  SimpleSelector _simpleSelector({bool allowParent}) {
    var start = scanner.state;
    allowParent ??= _allowParent;
    switch (scanner.peekChar()) {
      case $lbracket:
        return _attributeSelector();
      case $dot:
        return _classSelector();
      case $hash:
        return _idSelector();
      case $percent:
        var selector = _placeholderSelector();
        if (!_allowPlaceholder) {
          error("Placeholder selectors aren't allowed here.",
              scanner.spanFrom(start));
        }
        return selector;
      case $colon:
        return _pseudoSelector();
      case $ampersand:
        var selector = _parentSelector();
        if (!allowParent) {
          error(
              "Parent selectors aren't allowed here.", scanner.spanFrom(start));
        }
        return selector;

      default:
        return _typeOrUniversalSelector();
    }
  }

  /// Consumes an attribute selector.
  AttributeSelector _attributeSelector() {
    scanner.expectChar($lbracket);
    whitespace();

    var name = _attributeName();
    whitespace();
    if (scanner.scanChar($rbracket)) return AttributeSelector(name);

    var operator = _attributeOperator();
    whitespace();

    var next = scanner.peekChar();
    var value = next == $single_quote || next == $double_quote
        ? string()
        : identifier();
    whitespace();

    next = scanner.peekChar();
    var modifier = next != null && isAlphabetic(next)
        ? String.fromCharCode(scanner.readChar())
        : null;

    scanner.expectChar($rbracket);
    return AttributeSelector.withOperator(name, operator, value,
        modifier: modifier);
  }

  /// Consumes a qualified name as part of an attribute selector.
  QualifiedName _attributeName() {
    if (scanner.scanChar($asterisk)) {
      scanner.expectChar($pipe);
      return QualifiedName(identifier(), namespace: "*");
    }

    var nameOrNamespace = identifier();
    if (scanner.peekChar() != $pipe || scanner.peekChar(1) == $equal) {
      return QualifiedName(nameOrNamespace);
    }

    scanner.readChar();
    return QualifiedName(identifier(), namespace: nameOrNamespace);
  }

  /// Consumes an attribute selector's operator.
  AttributeOperator _attributeOperator() {
    var start = scanner.state;
    switch (scanner.readChar()) {
      case $equal:
        return AttributeOperator.equal;

      case $tilde:
        scanner.expectChar($equal);
        return AttributeOperator.include;

      case $pipe:
        scanner.expectChar($equal);
        return AttributeOperator.dash;

      case $caret:
        scanner.expectChar($equal);
        return AttributeOperator.prefix;

      case $dollar:
        scanner.expectChar($equal);
        return AttributeOperator.suffix;

      case $asterisk:
        scanner.expectChar($equal);
        return AttributeOperator.substring;

      default:
        scanner.error('Expected "]".', position: start.position);
        throw "Unreachable";
    }
  }

  /// Consumes a class selector.
  ClassSelector _classSelector() {
    scanner.expectChar($dot);
    var name = identifier();
    return ClassSelector(name);
  }

  /// Consumes an ID selector.
  IDSelector _idSelector() {
    scanner.expectChar($hash);
    var name = identifier();
    return IDSelector(name);
  }

  /// Consumes a placeholder selector.
  PlaceholderSelector _placeholderSelector() {
    scanner.expectChar($percent);
    var name = identifier();
    return PlaceholderSelector(name);
  }

  /// Consumes a parent selector.
  ParentSelector _parentSelector() {
    scanner.expectChar($ampersand);
    var suffix = lookingAtIdentifierBody() ? identifierBody() : null;
    return ParentSelector(suffix: suffix);
  }

  /// Consumes a pseudo selector.
  PseudoSelector _pseudoSelector() {
    scanner.expectChar($colon);
    var element = scanner.scanChar($colon);
    var name = identifier();

    if (!scanner.scanChar($lparen)) {
      return PseudoSelector(name, element: element);
    }
    whitespace();

    var unvendored = unvendor(name);
    String argument;
    SelectorList selector;
    if (element) {
      if (_selectorPseudoElements.contains(unvendored)) {
        selector = _selectorList();
      } else {
        argument = declarationValue(allowEmpty: true);
      }
    } else if (_selectorPseudoClasses.contains(unvendored)) {
      selector = _selectorList();
    } else if (unvendored == "nth-child" || unvendored == "nth-last-child") {
      argument = _aNPlusB();
      whitespace();
      if (isWhitespace(scanner.peekChar(-1)) && scanner.peekChar() != $rparen) {
        expectIdentifier("of");
        argument += " of";
        whitespace();

        selector = _selectorList();
      }
    } else {
      argument = declarationValue(allowEmpty: true).trimRight();
    }
    scanner.expectChar($rparen);

    return PseudoSelector(name,
        element: element, argument: argument, selector: selector);
  }

  /// Consumes an [`An+B` production][An+B] and returns its text.
  ///
  /// [An+B]: https://drafts.csswg.org/css-syntax-3/#anb-microsyntax
  String _aNPlusB() {
    var buffer = StringBuffer();
    switch (scanner.peekChar()) {
      case $e:
      case $E:
        expectIdentifier("even");
        return "even";

      case $o:
      case $O:
        expectIdentifier("odd");
        return "odd";

      case $plus:
      case $minus:
        buffer.writeCharCode(scanner.readChar());
        break;
    }

    var first = scanner.peekChar();
    if (first != null && isDigit(first)) {
      while (isDigit(scanner.peekChar())) {
        buffer.writeCharCode(scanner.readChar());
      }
      whitespace();
      if (!scanIdentChar($n)) return buffer.toString();
    } else {
      expectIdentChar($n);
    }
    buffer.writeCharCode($n);
    whitespace();

    var next = scanner.peekChar();
    if (next != $plus && next != $minus) return buffer.toString();
    buffer.writeCharCode(scanner.readChar());
    whitespace();

    var last = scanner.peekChar();
    if (last == null || !isDigit(last)) scanner.error("Expected a number.");
    while (isDigit(scanner.peekChar())) {
      buffer.writeCharCode(scanner.readChar());
    }
    return buffer.toString();
  }

  /// Consumes a type selector or a universal selector.
  ///
  /// These are combined because either one could start with `*`.
  SimpleSelector _typeOrUniversalSelector() {
    var first = scanner.peekChar();
    if (first == $asterisk) {
      scanner.readChar();
      if (!scanner.scanChar($pipe)) return UniversalSelector();
      if (scanner.scanChar($asterisk)) {
        return UniversalSelector(namespace: "*");
      } else {
        return TypeSelector(QualifiedName(identifier(), namespace: "*"));
      }
    } else if (first == $pipe) {
      scanner.readChar();
      if (scanner.scanChar($asterisk)) {
        return UniversalSelector(namespace: "");
      } else {
        return TypeSelector(QualifiedName(identifier(), namespace: ""));
      }
    }

    var nameOrNamespace = identifier();
    if (!scanner.scanChar($pipe)) {
      return TypeSelector(QualifiedName(nameOrNamespace));
    } else if (scanner.scanChar($asterisk)) {
      return UniversalSelector(namespace: nameOrNamespace);
    } else {
      return TypeSelector(
          QualifiedName(identifier(), namespace: nameOrNamespace));
    }
  }
}
