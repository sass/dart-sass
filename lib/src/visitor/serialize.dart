// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../exception.dart';
import '../util/character.dart';
import '../value.dart';
import 'interface/css.dart';
import 'interface/selector.dart';
import 'interface/value.dart';

String toCss(CssNode node, {OutputStyle style, bool inspect: false}) {
  var visitor = new _SerializeCssVisitor(style: style, inspect: inspect);
  node.accept(visitor);
  var result = visitor._buffer.toString();
  if (result.codeUnits.any((codeUnit) => codeUnit > 0x7F)) {
    result = '@charset "UTF-8";\n$result';
  }

  // TODO(nweiz): Do this in a way that's not O(n), maybe using a custom buffer
  // that's not append-only.
  return result.trim();
}

// Note: this may throw an [InternalException] if [inspect] is `false`.
String valueToCss(Value value, {bool inspect: false}) {
  var visitor = new _SerializeCssVisitor(inspect: inspect);
  value.accept(visitor);
  return visitor._buffer.toString();
}

// Note: this may throw an [InternalException] if [inspect] is `false`.
String selectorToCss(Selector selector, {bool inspect: false}) {
  var visitor = new _SerializeCssVisitor(inspect: inspect);
  selector.accept(visitor);
  return visitor._buffer.toString();
}

class _SerializeCssVisitor
    implements CssVisitor, ValueVisitor, SelectorVisitor {
  final _buffer = new StringBuffer();

  var _indentation = 0;

  final bool _inspect;

  _SerializeCssVisitor({OutputStyle style, bool inspect: false})
      : _inspect = inspect;

  void visitStylesheet(CssStylesheet node) {
    for (var child in node.children) {
      if (_isInvisible(child)) continue;
      child.accept(this);
      _buffer.writeln();
    }
  }

  void visitComment(CssComment node) {
    var minimumIndentation = _minimumIndentation(node.text);
    if (minimumIndentation == null) {
      _buffer.writeln(node.text);
      return;
    }

    if (node.span != null) {
      minimumIndentation = math.min(minimumIndentation, node.span.start.column);
    }

    _writeIndentation();
    _writeWithIndent(node.text, minimumIndentation);
  }

  void visitAtRule(CssAtRule node) {
    _writeIndentation();
    _buffer.writeCharCode($at);
    _buffer.write(node.name);

    if (node.value != null) {
      _buffer.writeCharCode($space);
      _buffer.write(node.value.value);
    }

    if (node.isChildless) {
      _buffer.writeCharCode($semicolon);
    } else {
      _buffer.writeCharCode($space);
      _visitChildren(node.children);
    }
  }

  void visitMediaRule(CssMediaRule node) {
    _writeIndentation();
    _buffer.write("@media ");

    for (var query in node.queries) {
      visitMediaQuery(query);
    }

    _buffer.writeCharCode($space);
    _visitChildren(node.children);
  }

  void visitImport(CssImport node) {
    _writeIndentation();
    _buffer.write("@import ");
    _visitString(node.url.toString());
    _buffer.writeCharCode($semicolon);
  }

  void visitMediaQuery(CssMediaQuery query) {
    if (query.modifier != null) {
      _buffer.write(query.modifier.value);
      _buffer.writeCharCode($space);
    }

    if (query.type != null) {
      _buffer.write(query.type.value);
      if (query.features.isNotEmpty) _buffer.write(" and ");
    }

    _writeBetween(query.features, " and ", _buffer.write);
  }

  void visitStyleRule(CssStyleRule node) {
    _writeIndentation();
    node.selector.value.accept(this);
    _buffer.writeCharCode($space);
    _visitChildren(node.children);

    // TODO: only add an extra newline if this is a group end
    _buffer.writeln();
  }

  void visitSupportsRule(CssSupportsRule node) {
    _writeIndentation();
    _buffer.write("@supports ");
    _buffer.write(node.condition.value);
    _buffer.writeCharCode($space);
    _visitChildren(node.children);

    // TODO: only add an extra newline if this is a group end
    _buffer.writeln();
  }

  void visitDeclaration(CssDeclaration node) {
    _writeIndentation();
    _buffer.write(node.name.value);
    _buffer.writeCharCode($colon);
    if (node.isCustomProperty) {
      _writeCustomPropertyValue(node);
    } else {
      _buffer.writeCharCode($space);
      _visitValue(node.value);
    }
    _buffer.writeCharCode($semicolon);
  }

  void _writeCustomPropertyValue(CssDeclaration node) {
    var value = (node.value.value as SassString).text;

    var minimumIndentation = _minimumIndentation(value);
    if (minimumIndentation == null) {
      _buffer.write(value);
      return;
    }

    if (node.value.span != null) {
      minimumIndentation =
          math.min(minimumIndentation, node.name.span.start.column);
    }

    _writeWithIndent(value, minimumIndentation);
  }

  int _minimumIndentation(String text) {
    var scanner = new LineScanner(text);
    while (!scanner.isDone && scanner.readChar() != $lf) {}
    if (scanner.isDone) return null;

    int min;
    while (!scanner.isDone) {
      while (!scanner.isDone && scanner.scanChar($space)) {}
      if (scanner.isDone || scanner.scanChar($lf)) continue;
      min = min == null ? scanner.column : math.min(min, scanner.column);
      while (!scanner.isDone && scanner.readChar() != $lf) {}
    }

    return min;
  }

  void _writeWithIndent(String text, int minimumIndentation) {
    var scanner = new LineScanner(text);
    while (!scanner.isDone && scanner.peekChar() != $lf) {
      _buffer.writeCharCode(scanner.readChar());
    }

    while (!scanner.isDone) {
      _buffer.writeCharCode(scanner.readChar());
      for (var i = 0; i < minimumIndentation; i++) scanner.readChar();
      _writeIndentation();
      while (!scanner.isDone && scanner.peekChar() != $lf) {
        _buffer.writeCharCode(scanner.readChar());
      }
    }
  }

  // ## Values

  void _visitValue(CssValue<Value> value) {
    try {
      value.value.accept(this);
    } on InternalException catch (error) {
      throw new SassException(error.message, value.span);
    }
  }

  void visitBoolean(SassBoolean value) => _buffer.write(value.value.toString());

  void visitColor(SassColor value) {
    // TODO(nweiz): Use color names for named colors.
    if (value.alpha == 1) {
      _buffer.writeCharCode($hash);
      _writeHexComponent(value.red);
      _writeHexComponent(value.green);
      _writeHexComponent(value.blue);
    } else {
      // TODO: support precision in alpha, make sure we don't write exponential
      // notation.
      _buffer.write(
          "rgb(${value.red}, ${value.green}, ${value.blue}, ${value.alpha})");
    }
  }

  void _writeHexComponent(int color) {
    _buffer.writeCharCode(hexCharFor(color >> 4));
    _buffer.writeCharCode(hexCharFor(color & 0xF));
  }

  void visitList(SassList value) {
    if (value.hasBrackets) {
      _buffer.writeCharCode($lbracket);
    } else if (value.contents.isEmpty) {
      if (!_inspect) throw new InternalException("() isn't a valid CSS value");
      _buffer.write("()");
      return;
    }

    _writeBetween(
        value.contents.where((element) => !element.isBlank),
        value.separator == ListSeparator.space ? " " : ", ",
        _inspect
            ? (element) {
                var needsParens = _elementNeedsParens(value.separator, element);
                if (needsParens) _buffer.writeCharCode($lparen);
                element.accept(this);
                if (needsParens) _buffer.writeCharCode($rparen);
              }
            : (element) => element.accept(this));

    if (value.hasBrackets) _buffer.writeCharCode($rbracket);
  }

  bool _elementNeedsParens(ListSeparator separator, Value value) {
    if (value is SassList) {
      if (value.contents.length < 2) return false;
      if (value.hasBrackets) return false;
      return separator == ListSeparator.comma
          ? value.separator == ListSeparator.comma
          : value.separator != ListSeparator.undecided;
    }
    return false;
  }

  void visitMap(SassMap map) {
    if (!_inspect) throw new InternalException("$map isn't a valid CSS value.");
    _buffer.writeCharCode($lparen);
    _writeBetween(map.contents.keys, ", ", (key) {
      _writeMapElement(key);
      _buffer.write(": ");
      _writeMapElement(map.contents[key]);
    });
    _buffer.writeCharCode($rparen);
  }

  void _writeMapElement(Value value) {
    var needsParens = value is SassList &&
        value.separator == ListSeparator.comma &&
        !value.hasBrackets;
    if (needsParens) _buffer.writeCharCode($lparen);
    value.accept(this);
    if (needsParens) _buffer.writeCharCode($rparen);
  }

  void visitNull(SassNull value) {
    _buffer.write("null");
  }

  // TODO(nweiz): Support precision and don't support exponent notation.
  void visitNumber(SassNumber value) {
    _buffer.write(value.value);

    if (!_inspect) {
      if (value.numeratorUnits.length > 1 ||
          value.denominatorUnits.isNotEmpty) {
        throw new InternalException("$value isn't a valid CSS value.");
      }

      if (value.numeratorUnits.isNotEmpty) {
        _buffer.write(value.numeratorUnits.first);
      }
    } else {
      _buffer.write(value.unitString);
    }
  }

  void visitString(SassString string) {
    _buffer.write(string.hasQuotes
        ? _visitString(string.text)
        : string.text.replaceAll("\n", " "));
  }

  String _visitString(String string, {bool forceDoubleQuote: false}) {
    var includesSingleQuote = false;
    var includesDoubleQuote = false;
    var buffer = new StringBuffer();
    for (var i = 0; i < string.length; i++) {
      var char = string.codeUnitAt(i);
      switch (char) {
        case $single_quote:
          if (forceDoubleQuote) {
            buffer.writeCharCode($single_quote);
          } else if (includesDoubleQuote) {
            return _visitString(string, forceDoubleQuote: true);
          } else {
            includesSingleQuote = true;
            buffer.writeCharCode($single_quote);
          }
          break;

        case $double_quote:
          if (forceDoubleQuote) {
            buffer.writeCharCode($backslash);
            buffer.writeCharCode($double_quote);
          } else if (includesSingleQuote) {
            return _visitString(string, forceDoubleQuote: true);
          } else {
            includesDoubleQuote = true;
            buffer.writeCharCode($double_quote);
          }
          break;

        case $cr:
        case $lf:
        case $ff:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode(hexCharFor(char));
          if (string.length == i + 1) break;

          var next = string.codeUnitAt(i + 1);
          if (isHex(next) || next == $space || next == $tab) {
            buffer.writeCharCode($space);
          }
          break;

        case $backslash:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode($backslash);
          break;

        default:
          buffer.writeCharCode(char);
          break;
      }
    }

    var doubleQuote = forceDoubleQuote || !includesDoubleQuote;
    return doubleQuote ? '"$buffer"' : "'$buffer'";
  }

  // ## Selectors

  void visitAttributeSelector(AttributeSelector attribute) {
    _buffer.writeCharCode($lbracket);
    _buffer.write(attribute.name);
    if (attribute.op == null) {
      _buffer.write(attribute.op);
      // TODO: quote the value if it's not an identifier
      _buffer.write(attribute.value);
    }
    _buffer.writeCharCode($rbracket);
  }

  void visitClassSelector(ClassSelector klass) {
    _buffer.writeCharCode($dot);
    _buffer.write(klass.name);
  }

  void visitComplexSelector(ComplexSelector complex) {
    _writeBetween(complex.components, " ", (component) {
      if (component is CompoundSelector) {
        visitCompoundSelector(component);
      } else {
        _buffer.write(component);
      }
    });
  }

  void visitCompoundSelector(CompoundSelector compound) {
    for (var simple in compound.components) {
      simple.accept(this);
    }
  }

  void visitIDSelector(IDSelector id) {
    _buffer.writeCharCode($hash);
    _buffer.write(id.name);
  }

  void visitSelectorList(SelectorList list) {
    var complexes = _inspect
        ? list.components
        : list.components.where((complex) => !complex.containsPlaceholder);

    var first = true;
    for (var complex in complexes) {
      if (first) {
        first = false;
      } else {
        _buffer.writeCharCode($comma);
        _buffer.writeCharCode(complex.lineBreak ? $lf : $space);
      }
      visitComplexSelector(complex);
    }
  }

  void visitParentSelector(ParentSelector parent) {
    _buffer.writeCharCode($ampersand);
    if (parent.suffix != null) _buffer.write(parent.suffix);
  }

  void visitPlaceholderSelector(PlaceholderSelector placeholder) {
    _buffer.writeCharCode($percent);
    _buffer.write(placeholder.name);
  }

  void visitPseudoSelector(PseudoSelector pseudo) {
    _buffer.writeCharCode($colon);
    if (pseudo.type == PseudoType.element) _buffer.writeCharCode($colon);
    _buffer.write(pseudo.name);
    if (pseudo.argument == null && pseudo.selector == null) return;

    _buffer.writeCharCode($lparen);
    if (pseudo.argument != null) {
      _buffer.write(pseudo.argument);
      if (pseudo.selector != null) _buffer.writeCharCode($space);
    }
    if (pseudo.selector != null) _buffer.write(pseudo.selector);
    _buffer.writeCharCode($rparen);
  }

  void visitTypeSelector(TypeSelector type) {
    _buffer.write(type.name);
  }

  void visitUniversalSelector(UniversalSelector universal) {
    if (universal.namespace != null) {
      _buffer.write(universal.namespace);
      _buffer.writeCharCode($pipe);
    }
    _buffer.writeCharCode($asterisk);
  }

  // ## Utilities

  void _visitChildren(Iterable<CssNode> children) {
    _buffer.writeCharCode($lbrace);
    if (children.every(_isInvisible)) {
      _buffer.writeCharCode($rbrace);
      return;
    }

    _buffer.writeln();
    _indent(() {
      for (var child in children) {
        if (_isInvisible(child)) continue;
        child.accept(this);
        _buffer.writeln();
      }
    });
    _writeIndentation();
    _buffer.writeCharCode($rbrace);
  }

  void _writeIndentation() {
    for (var i = 0; i < _indentation; i++) {
      _buffer.writeCharCode($space);
      _buffer.writeCharCode($space);
    }
  }

  void _writeBetween/*<T>*/(
      Iterable/*<T>*/ iterable, String text, void callback(/*=T*/ value)) {
    var first = true;
    for (var value in iterable) {
      if (first) {
        first = false;
      } else {
        _buffer.write(text);
      }
      callback(value);
    }
  }

  void _indent(void callback()) {
    _indentation++;
    callback();
    _indentation--;
  }

  bool _isInvisible(CssNode node) => !_inspect && node.isInvisible;
}

class OutputStyle {
  static const expanded = const OutputStyle._("expanded");
  static const nested = const OutputStyle._("nested");

  final String _name;

  const OutputStyle._(this._name);

  String toString() => _name;
}
