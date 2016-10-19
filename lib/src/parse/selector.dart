// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/selector.dart';
import '../util/character.dart';
import '../utils.dart';
import 'parser.dart';

/// Pseudo-class selectors that take unadorned selectors as arguments.
final _selectorPseudoClasses = new Set.from(
    ["not", "matches", "current", "any", "has", "host", "host-context"]);

/// A parser for selectors.
class SelectorParser extends Parser {
  /// Whether this parser allows the parent selector `&`.
  final bool _allowParent;

  SelectorParser(String contents, {url, bool allowParent: true})
      : _allowParent = allowParent,
        super(contents, url: url);

  SelectorList parse() {
    return wrapSpanFormatException(() {
      var selector = _selectorList();
      scanner.expectDone();
      return selector;
    });
  }

  CompoundSelector parseCompoundSelector() {
    return wrapSpanFormatException(() {
      var compound = _compoundSelector();
      scanner.expectDone();
      return compound;
    });
  }

  SimpleSelector parseSimpleSelector() {
    return wrapSpanFormatException(() {
      var simple = _simpleSelector();
      scanner.expectDone();
      return simple;
    });
  }

  /// Consumes a selector list.
  SelectorList _selectorList() {
    var components = <ComplexSelector>[];

    whitespace();
    var previousLine = scanner.line;
    do {
      whitespace();
      var next = scanner.peekChar();
      if (next == $comma) continue;
      if (scanner.isDone) break;

      var lineBreak = scanner.line != previousLine;
      if (lineBreak) previousLine = scanner.line;
      components.add(_complexSelector(lineBreak: lineBreak));
    } while (scanner.scanChar($comma));

    return new SelectorList(components);
  }

  /// Consumes a complex selector.
  ///
  /// If [lineBreak] is `true`, that indicates that there was a line break
  /// before this selector.
  ComplexSelector _complexSelector({bool lineBreak: false}) {
    var components = <ComplexSelectorComponent>[];

    loop:
    while (true) {
      whitespace();

      ComplexSelectorComponent component;
      var next = scanner.peekChar();
      switch (next) {
        case $plus:
          scanner.readChar();
          component = Combinator.nextSibling;
          break;

        case $gt:
          scanner.readChar();
          component = Combinator.child;
          break;

        case $tilde:
          scanner.readChar();
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
          if (next == null || !lookingAtIdentifier()) break loop;
          component = _compoundSelector();
          break;
      }

      components.add(component);
    }

    return new ComplexSelector(components, lineBreak: lineBreak);
  }

  /// Consumes a compound selector.
  CompoundSelector _compoundSelector() {
    var components = <SimpleSelector>[_simpleSelector()];

    while (isSimpleSelectorStart(scanner.peekChar())) {
      components.add(_simpleSelector(allowParent: false));
    }

    // TODO: support "*E" (or talk to Chris about dropping support for hacks).
    return new CompoundSelector(components);
  }

  /// Consumes a simple selector.
  ///
  /// If [allowParent] is passed, it controls whether the parent selector `&` is
  /// allowed. Otherwise, it defaults to [_allowParent].
  SimpleSelector _simpleSelector({bool allowParent}) {
    allowParent ??= _allowParent;
    switch (scanner.peekChar()) {
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

  /// Consumes an attribute selector.
  AttributeSelector _attributeSelector() {
    scanner.expectChar($lbracket);
    whitespace();

    var name = _attributeName();
    whitespace();
    if (scanner.scanChar($rbracket)) return new AttributeSelector(name);

    var operator = _attributeOperator();
    whitespace();

    var next = scanner.peekChar();
    var value = next == $single_quote || next == $double_quote
        ? string()
        : identifier();
    whitespace();

    scanner.expectChar($rbracket);
    return new AttributeSelector.withOperator(name, operator, value);
  }

  /// Consumes a qualified name as part of an attribute selector.
  QualifiedName _attributeName() {
    if (scanner.scanChar($asterisk)) {
      scanner.expectChar($pipe);
      return new QualifiedName(identifier(), namespace: "*");
    }

    var nameOrNamespace = identifier();
    if (scanner.peekChar() != $pipe || scanner.peekChar(1) == $equal) {
      return new QualifiedName(nameOrNamespace);
    }

    scanner.readChar();
    return new QualifiedName(identifier(), namespace: nameOrNamespace);
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
    return new ClassSelector(name);
  }

  /// Consumes an ID selector.
  IDSelector _idSelector() {
    scanner.expectChar($hash);
    var name = identifier();
    return new IDSelector(name);
  }

  /// Consumes a placeholder selector.
  PlaceholderSelector _placeholderSelector() {
    scanner.expectChar($percent);
    var name = identifier();
    return new PlaceholderSelector(name);
  }

  /// Consumes a parent selector.
  ParentSelector _parentSelector() {
    scanner.expectChar($ampersand);
    var next = scanner.peekChar();
    var suffix = next != null && (isName(next) || next == $backslash)
        ? identifier()
        : null;
    return new ParentSelector(suffix: suffix);
  }

  /// Consumes a pseudo selector.
  PseudoSelector _pseudoSelector() {
    scanner.expectChar($colon);
    var element = scanner.scanChar($colon);
    var name = identifier();

    if (!scanner.scanChar($lparen)) {
      return new PseudoSelector(name, element: element);
    }
    whitespace();

    var unvendored = unvendor(name);
    String argument;
    SelectorList selector;
    if (element) {
      argument = declarationValue();
    } else if (_selectorPseudoClasses.contains(unvendored)) {
      selector = _selectorList();
    } else if (unvendored == "nth-child" || unvendored == "nth-last-child") {
      argument = rawText(_aNPlusB);
      if (scanWhitespace()) {
        expectIdentifier("of", ignoreCase: true);
        argument += " of";
        whitespace();

        selector = _selectorList();
      }
    } else {
      argument = declarationValue();
    }
    scanner.expectChar($rparen);

    return new PseudoSelector(name,
        element: element, argument: argument, selector: selector);
  }

  /// Consumes an [`An+B` production][An+B].
  ///
  /// [An+B]: https://drafts.csswg.org/css-syntax-3/#anb-microsyntax
  void _aNPlusB() {
    switch (scanner.peekChar()) {
      case $e:
      case $E:
        expectIdentifier("even", ignoreCase: true);
        return;

      case $o:
      case $O:
        expectIdentifier("odd", ignoreCase: true);
        return;

      case $plus:
      case $minus:
        scanner.readChar();
        break;
    }

    var first = scanner.peekChar();
    if (first != null && isDigit(first)) {
      while (isDigit(scanner.peekChar())) {
        scanner.readChar();
      }
      whitespace();
      if (!scanCharIgnoreCase($n)) return;
    } else {
      expectCharIgnoreCase($n);
    }
    whitespace();

    var next = scanner.peekChar();
    if (next != $plus && next != $minus) return;
    scanner.readChar();
    whitespace();

    var last = scanner.peekChar();
    if (last == null || !isDigit(last)) scanner.error("Expected a number.");
    while (isDigit(scanner.peekChar())) {
      scanner.readChar();
    }
  }

  /// Consumes a type selector or a universal selector.
  ///
  /// These are combined because either one could start with `*`.
  SimpleSelector _typeOrUniversalSelector() {
    var first = scanner.peekChar();
    if (first == $asterisk) {
      scanner.readChar();
      if (!scanner.scanChar($pipe)) return new UniversalSelector();
      if (scanner.scanChar($asterisk)) {
        return new UniversalSelector(namespace: "*");
      } else {
        return new TypeSelector(
            new QualifiedName(identifier(), namespace: "*"));
      }
    } else if (first == $pipe) {
      scanner.readChar();
      if (scanner.scanChar($asterisk)) {
        return new UniversalSelector(namespace: "");
      } else {
        return new TypeSelector(new QualifiedName(identifier(), namespace: ""));
      }
    }

    var nameOrNamespace = identifier();
    if (!scanner.scanChar($pipe)) {
      return new TypeSelector(new QualifiedName(nameOrNamespace));
    }

    return new TypeSelector(
        new QualifiedName(identifier(), namespace: nameOrNamespace));
  }
}
