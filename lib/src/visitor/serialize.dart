// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../color_names.dart';
import '../exception.dart';
import '../util/character.dart';
import '../util/number.dart';
import '../value.dart';
import 'interface/css.dart';
import 'interface/selector.dart';
import 'interface/value.dart';

/// Converts [node] to a CSS string.
///
/// If [style] is passed, it controls the style of the resulting CSS. It
/// defaults to [OutputStyle.expanded].
///
/// If [inspect] is `true`, this will emit an unambiguous representation of the
/// source structure. Note however that, although this will be valid SCSS, it
/// may not be valid CSS. If [inspect] is `false` and [node] contains any values
/// that can't be represented in plain CSS, throws a [SassException].
String serialize(CssNode node,
    {OutputStyle style,
    bool inspect: false,
    bool useSpaces: true,
    int indentWidth,
    LineFeed lineFeed}) {
  indentWidth ??= 2;
  var visitor = new _SerializeVisitor(
      style: style,
      inspect: inspect,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed);
  node.accept(visitor);
  var result = visitor._buffer.toString();
  if (result.codeUnits.any((codeUnit) => codeUnit > 0x7F)) {
    result = '@charset "UTF-8";\n$result';
  }
  return result;
}

/// Converts [value] to a CSS string.
///
/// If [inspect] is `true`, this will emit an unambiguous representation of the
/// source structure. Note however that, although this will be valid SCSS, it
/// may not be valid CSS. If [inspect] is `false` and [value] can't be
/// represented in plain CSS, throws a [SassScriptException].
///
/// If [quote] is `false`, quoted strings are emitted without quotes.
String serializeValue(Value value, {bool inspect: false, bool quote: true}) {
  var visitor = new _SerializeVisitor(inspect: inspect, quote: quote);
  value.accept(visitor);
  return visitor._buffer.toString();
}

/// Converts [selector] to a CSS string.
///
/// If [inspect] is `true`, this will emit an unambiguous representation of the
/// source structure. Note however that, although this will be valid SCSS, it
/// may not be valid CSS. If [inspect] is `false` and [selector] can't be
/// represented in plain CSS, throws a [SassScriptException].
String serializeSelector(Selector selector, {bool inspect: false}) {
  var visitor = new _SerializeVisitor(inspect: inspect);
  selector.accept(visitor);
  return visitor._buffer.toString();
}

/// A visitor that converts CSS syntax trees to plain strings.
class _SerializeVisitor implements CssVisitor, ValueVisitor, SelectorVisitor {
  /// A buffer that contains the CSS produced so far.
  final _buffer = new StringBuffer();

  /// The current indentation of the CSS output.
  var _indentation = 0;

  /// Whether we're emitting an unambiguous representation of the source
  /// structure, as opposed to valid CSS.
  final bool _inspect;

  /// Whether quoted strings should be emitted with quotes.
  final bool _quote;

  /// The character to use for indentation; either space or tab.
  final int _indentCharacter;

  /// The number of spaces or tabs to be used for indentation.
  final int _indentWidth;

  /// The characters to use for a line feed.
  final LineFeed _lineFeed;

  _SerializeVisitor(
      {OutputStyle style,
      bool inspect: false,
      bool quote: true,
      bool useSpaces: true,
      int indentWidth,
      LineFeed lineFeed})
      : _inspect = inspect,
        _quote = quote,
        _indentCharacter = useSpaces ? $space : $tab,
        _indentWidth = indentWidth ?? 2,
        _lineFeed = lineFeed ?? LineFeed.lf {
    RangeError.checkValueInInterval(_indentWidth, 0, 10, "indentWidth");
  }

  void visitStylesheet(CssStylesheet node) {
    CssNode previous;
    for (var i = 0; i < node.children.length; i++) {
      var child = node.children[i];
      if (_isInvisible(child)) continue;

      if (previous != null) {
        _buffer.write(_lineFeed.text);
        if (previous.isGroupEnd) _buffer.write(_lineFeed.text);
      }
      previous = child;

      child.accept(this);
    }
  }

  void visitComment(CssComment node) {
    var minimumIndentation = _minimumIndentation(node.text);
    if (minimumIndentation == null) {
      _writeIndentation();
      _buffer.write(node.text);
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
    _writeBetween(node.queries, ", ", _visitMediaQuery);
    _buffer.writeCharCode($space);
    _visitChildren(node.children);
  }

  void visitImport(CssImport node) {
    _writeIndentation();
    _buffer.write("@import ");
    _buffer.write(node.url.value);

    if (node.supports != null) {
      _buffer.writeCharCode($space);
      _buffer.write(node.supports.value);
    }

    if (node.media != null) {
      _buffer.writeCharCode($space);
      _writeBetween(node.media, ', ', _visitMediaQuery);
    }

    _buffer.writeCharCode($semicolon);
  }

  void visitKeyframeBlock(CssKeyframeBlock node) {
    _writeIndentation();
    _writeBetween(node.selector.value, ", ", _buffer.write);
    _buffer.writeCharCode($space);
    _visitChildren(node.children);
  }

  void _visitMediaQuery(CssMediaQuery query) {
    if (query.modifier != null) {
      _buffer.write(query.modifier);
      _buffer.writeCharCode($space);
    }

    if (query.type != null) {
      _buffer.write(query.type);
      if (query.features.isNotEmpty) _buffer.write(" and ");
    }

    _writeBetween(query.features, " and ", _buffer.write);
  }

  void visitStyleRule(CssStyleRule node) {
    _writeIndentation();
    node.selector.value.accept(this);
    _buffer.writeCharCode($space);
    _visitChildren(node.children);
  }

  void visitSupportsRule(CssSupportsRule node) {
    _writeIndentation();
    _buffer.write("@supports ");
    _buffer.write(node.condition.value);
    _buffer.writeCharCode($space);
    _visitChildren(node.children);
  }

  void visitDeclaration(CssDeclaration node) {
    _writeIndentation();
    _buffer.write(node.name.value);
    _buffer.writeCharCode($colon);
    if (_shouldReindentValue(node)) {
      _writeReindentedValue(node);
    } else {
      _buffer.writeCharCode($space);
      _visitValue(node.value);
    }
    _buffer.writeCharCode($semicolon);
  }

  /// Returns whether [node]'s value should be re-indented when being written to
  /// the stylesheet.
  ///
  /// We only re-indent custom property values that were parsed as custom
  /// properties, which we detect as unquoted strings. It's possible to have
  /// false positives here, since someone could write `#{--foo}: unquoted`, but
  /// that's unlikely enough that we can spare the extra time a no-op
  /// reindenting will take.
  bool _shouldReindentValue(CssDeclaration node) {
    if (!node.name.value.startsWith("--")) return false;
    var value = node.value.value;
    return value is SassString && !value.hasQuotes;
  }

  /// Emits the value of [node], re-indented relative to the current indentation.
  void _writeReindentedValue(CssDeclaration node) {
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

  /// Returns the indentation level of the least-indented, non-empty line in
  /// [text].
  int _minimumIndentation(String text) {
    var scanner = new LineScanner(text);
    while (!scanner.isDone && scanner.readChar() != $lf) {}
    if (scanner.isDone) return null;

    int min;
    while (!scanner.isDone) {
      while (!scanner.isDone) {
        var next = scanner.peekChar();
        if (next != $space && next != $tab) break;
        scanner.readChar();
      }
      if (scanner.isDone || scanner.scanChar($lf)) continue;
      min = min == null ? scanner.column : math.min(min, scanner.column);
      while (!scanner.isDone && scanner.readChar() != $lf) {}
    }

    return min;
  }

  /// Writes [text] to [_buffer], adding [minimumIndentation] to each non-empty
  /// line.
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

  /// Converts [value] to a plain CSS string, converting any
  /// [SassScriptException]s to [SassException]s.
  void _visitValue(CssValue<Value> value) {
    try {
      value.value.accept(this);
    } on SassScriptException catch (error) {
      throw new SassException(error.message, value.span);
    }
  }

  void visitBoolean(SassBoolean value) => _buffer.write(value.value.toString());

  void visitColor(SassColor value) {
    if (value.original != null) {
      _buffer.write(value.original);
    } else if (namesByColor.containsKey(value) &&
        // Always emit generated transparent colors in rgba format. This works
        // around an IE bug. See sass/sass#1782.
        !fuzzyEquals(value.alpha, 0)) {
      _buffer.write(namesByColor[value]);
    } else if (value.alpha == 1) {
      _buffer.writeCharCode($hash);
      _writeHexComponent(value.red);
      _writeHexComponent(value.green);
      _writeHexComponent(value.blue);
    } else {
      _buffer.write("rgba(${value.red}, ${value.green}, ${value.blue}, ");
      _writeNumber(value.alpha);
      _buffer.writeCharCode($rparen);
    }
  }

  /// Emits [color] as a hex character pair.
  void _writeHexComponent(int color) {
    assert(color < 0x100);
    _buffer.writeCharCode(hexCharFor(color >> 4));
    _buffer.writeCharCode(hexCharFor(color & 0xF));
  }

  void visitFunction(SassFunction function) {
    if (!_inspect) {
      throw new SassScriptException("$function isn't a valid CSS value.");
    }

    _buffer.write("get-function(");
    _visitQuotedString(function.callable.name);
    _buffer.writeCharCode($rparen);
  }

  void visitList(SassList value) {
    if (value.hasBrackets) {
      _buffer.writeCharCode($lbracket);
    } else if (value.contents.isEmpty) {
      if (!_inspect) {
        throw new SassScriptException("() isn't a valid CSS value");
      }
      _buffer.write("()");
      return;
    }

    var singleton = _inspect &&
        value.contents.length == 1 &&
        value.separator == ListSeparator.comma;
    if (singleton && !value.hasBrackets) _buffer.writeCharCode($lparen);

    _writeBetween<Value>(
        _inspect
            ? value.contents
            : value.contents.where((element) => !element.isBlank),
        value.separator == ListSeparator.space ? " " : ", ",
        _inspect
            ? (element) {
                var needsParens = _elementNeedsParens(value.separator, element);
                if (needsParens) _buffer.writeCharCode($lparen);
                element.accept(this);
                if (needsParens) _buffer.writeCharCode($rparen);
              }
            : (element) {
                element.accept(this);
              });

    if (singleton) {
      _buffer.writeCharCode($comma);
      if (!value.hasBrackets) _buffer.writeCharCode($rparen);
    }

    if (value.hasBrackets) _buffer.writeCharCode($rbracket);
  }

  /// Returns whether [value] needs parentheses as an element in a list with the
  /// given [separator].
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
    if (!_inspect) {
      throw new SassScriptException("$map isn't a valid CSS value.");
    }
    _buffer.writeCharCode($lparen);
    _writeBetween<Value>(map.contents.keys, ", ", (key) {
      _writeMapElement(key);
      _buffer.write(": ");
      _writeMapElement(map.contents[key]);
    });
    _buffer.writeCharCode($rparen);
  }

  /// Writes [value] as key or value in a map, with parentheses as necessary.
  void _writeMapElement(Value value) {
    var needsParens = value is SassList &&
        value.separator == ListSeparator.comma &&
        !value.hasBrackets;
    if (needsParens) _buffer.writeCharCode($lparen);
    value.accept(this);
    if (needsParens) _buffer.writeCharCode($rparen);
  }

  void visitNull(SassNull value) {
    if (_inspect) _buffer.write("null");
  }

  void visitNumber(SassNumber value) {
    if (value.asSlash != null) {
      _buffer.write(value.asSlash);
      return;
    }

    _writeNumber(value.value);

    if (!_inspect) {
      if (value.numeratorUnits.length > 1 ||
          value.denominatorUnits.isNotEmpty) {
        throw new SassScriptException("$value isn't a valid CSS value.");
      }

      if (value.numeratorUnits.isNotEmpty) {
        _buffer.write(value.numeratorUnits.first);
      }
    } else {
      _buffer.write(value.unitString);
    }
  }

  /// Writes [number] without exponent notation and with at most
  /// [SassNumber.precision] digits after the decimal point.
  void _writeNumber(num number) {
    // Dart always converts integers to strings in the obvious way, so all we
    // have to do is clamp doubles that are close to being integers.
    var integer = fuzzyAsInt(number);
    if (integer != null) {
      _buffer.write(integer);
      return;
    }

    var text = number.toString();
    if (text.contains("e")) text = _removeExponent(text);

    // Any double that doesn't contain "e" and is less than
    // `SassNumber.precision + 2` digits long is guaranteed to be safe to emit
    // directly, since it'll contain at most `0.` followed by
    // [SassNumber.precision] digits.
    if (text.length < SassNumber.precision + 2) {
      _buffer.write(text);
      return;
    }

    _writeDecimal(text);
  }

  /// Assuming [text] is a double written in exponent notation, returns a string
  /// representation of that double without exponent notation.
  String _removeExponent(String text) {
    var buffer = new StringBuffer();
    int exponent;
    for (var i = 0; i < text.length; i++) {
      var codeUnit = text.codeUnitAt(i);
      if (codeUnit == $e) {
        exponent = int.parse(text.substring(i + 1, text.length));
        break;
      } else if (codeUnit != $dot) {
        buffer.writeCharCode(codeUnit);
      }
    }

    if (exponent > 0) {
      for (var i = 0; i < exponent; i++) {
        buffer.writeCharCode($0);
      }
      return buffer.toString();
    } else {
      var result = new StringBuffer();
      var negative = text.codeUnitAt(0) == $minus;
      if (negative) result.writeCharCode($minus);
      result.write("0.");
      for (var i = -1; i > exponent; i--) {
        result.writeCharCode($0);
      }
      result.write(negative ? buffer.toString().substring(1) : buffer);
      return result.toString();
    }
  }

  /// Assuming [text] is a double written without exponent notation, writes it
  /// to [_buffer] with at most [SassNumber.precision] digits after the decimal.
  void _writeDecimal(String text) {
    var textIndex = 0;
    for (; textIndex < text.length; textIndex++) {
      var codeUnit = text.codeUnitAt(textIndex);
      _buffer.writeCharCode(codeUnit);
      if (codeUnit == $dot) {
        textIndex++;
        break;
      }
    }
    if (textIndex == text.length) return;

    // We need to ensure that we write at most [SassNumber.precision] digits
    // after the decimal point, and that we round appropriately if necessary. To
    // do this, we maintain an intermediate buffer of decimal digits, which we
    // then convert to text.
    var digits = new Uint8List(SassNumber.precision);
    var digitsIndex = 0;
    while (textIndex < text.length && digitsIndex < digits.length) {
      digits[digitsIndex++] = asDecimal(text.codeUnitAt(textIndex++));
    }

    // Round the trailing digits in [digits] up if necessary. We can be
    // confident this won't cause us to need to round anything before the
    // decimal, because otherwise the number would be [fuzzyIsInt].
    if (textIndex != text.length &&
        asDecimal(text.codeUnitAt(textIndex)) >= 5) {
      while (digitsIndex >= 0) {
        var newDigit = ++digits[digitsIndex - 1];
        if (newDigit != 10) break;
        digitsIndex--;
      }
    }

    // Remove trailing zeros.
    while (digitsIndex >= 0 && digits[digitsIndex - 1] == 0) {
      digitsIndex--;
    }

    for (var i = 0; i < digitsIndex; i++) {
      _buffer.writeCharCode(decimalCharFor(digits[i]));
    }
  }

  void visitString(SassString string) {
    if (_quote && string.hasQuotes) {
      _visitQuotedString(string.text);
    } else {
      _visitUnquotedString(string.text);
    }
  }

  /// Writes a quoted string with [string] contents to [_buffer].
  ///
  /// By default, this detects which type of quote to use based on the contents
  /// of the string. If [forceDoubleQuote] is `true`, this always uses a double
  /// quote.
  void _visitQuotedString(String string, {bool forceDoubleQuote: false}) {
    var includesSingleQuote = false;
    var includesDoubleQuote = false;

    var buffer = forceDoubleQuote ? _buffer : new StringBuffer();
    if (forceDoubleQuote) buffer.writeCharCode($double_quote);
    for (var i = 0; i < string.length; i++) {
      var char = string.codeUnitAt(i);
      switch (char) {
        case $single_quote:
          if (forceDoubleQuote) {
            buffer.writeCharCode($single_quote);
          } else if (includesDoubleQuote) {
            _visitQuotedString(string, forceDoubleQuote: true);
            return;
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
            _visitQuotedString(string, forceDoubleQuote: true);
            return;
          } else {
            includesDoubleQuote = true;
            buffer.writeCharCode($double_quote);
          }
          break;

        // Write newline characters and unprintable ASCII characters as escapes.
        case $nul:
        case $soh:
        case $stx:
        case $etx:
        case $eot:
        case $enq:
        case $ack:
        case $bel:
        case $bs:
        case $lf:
        case $vt:
        case $ff:
        case $cr:
        case $so:
        case $si:
        case $dle:
        case $dc1:
        case $dc2:
        case $dc3:
        case $dc4:
        case $nak:
        case $syn:
        case $etb:
        case $can:
        case $em:
        case $sub:
        case $esc:
        case $fs:
        case $gs:
        case $rs:
        case $us:
          buffer.writeCharCode($backslash);
          if (char > 0xF) buffer.writeCharCode(hexCharFor(char >> 4));
          buffer.writeCharCode(hexCharFor(char & 0xF));
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

    if (forceDoubleQuote) {
      buffer.writeCharCode($double_quote);
    } else {
      var quote = includesDoubleQuote ? $single_quote : $double_quote;
      _buffer.writeCharCode(quote);
      _buffer.write(buffer);
      _buffer.writeCharCode(quote);
    }
  }

  /// Writes an unquoted string with [string] contents to [_buffer].
  void _visitUnquotedString(String string) {
    var afterNewline = false;
    for (var i = 0; i < string.length; i++) {
      var char = string.codeUnitAt(i);
      switch (char) {
        case $lf:
          _buffer.writeCharCode($space);
          afterNewline = true;
          break;

        case $space:
          if (!afterNewline) _buffer.writeCharCode($space);
          break;

        default:
          _buffer.writeCharCode(char);
          afterNewline = false;
          break;
      }
    }
  }

  // ## Selectors

  void visitAttributeSelector(AttributeSelector attribute) {
    _buffer.writeCharCode($lbracket);
    _buffer.write(attribute.name);
    if (attribute.op != null) {
      _buffer.write(attribute.op);
      if (_isIdentifier(attribute.value)) {
        _buffer.write(attribute.value);
      } else {
        _visitQuotedString(attribute.value);
      }
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
    var start = _buffer.length;
    for (var simple in compound.components) {
      simple.accept(this);
    }

    // If we emit an empty compound, it's because all of the components got
    // optimized out because they match all selectors, so we just emit the
    // universal selector.
    if (_buffer.length == start) _buffer.writeCharCode($asterisk);
  }

  void visitIDSelector(IDSelector id) {
    _buffer.writeCharCode($hash);
    _buffer.write(id.name);
  }

  void visitSelectorList(SelectorList list) {
    var complexes = _inspect
        ? list.components
        : list.components.where((complex) => !complex.isInvisible);

    var first = true;
    for (var complex in complexes) {
      if (first) {
        first = false;
      } else {
        _buffer.writeCharCode($comma);
        if (complex.lineBreak) {
          _buffer.write(_lineFeed.text);
        } else {
          _buffer.writeCharCode($space);
        }
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
    // `:not(%a)` is semantically identical to `*`.
    if (pseudo.selector != null &&
        pseudo.name == 'not' &&
        pseudo.selector.isInvisible) {
      return;
    }

    _buffer.writeCharCode($colon);
    if (pseudo.isElement) _buffer.writeCharCode($colon);
    _buffer.write(pseudo.name);
    if (pseudo.argument == null && pseudo.selector == null) return;

    _buffer.writeCharCode($lparen);
    if (pseudo.argument != null) {
      _buffer.write(pseudo.argument);
      if (pseudo.selector != null) _buffer.writeCharCode($space);
    }
    if (pseudo.selector != null) visitSelectorList(pseudo.selector);
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

  /// Emits [children] in a block.
  void _visitChildren(List<CssNode> children) {
    _buffer.writeCharCode($lbrace);
    if (children.every(_isInvisible)) {
      _buffer.writeCharCode($rbrace);
      return;
    }

    _buffer.write(_lineFeed.text);
    _indent(() {
      CssNode previous;
      for (var i = 0; i < children.length; i++) {
        var child = children[i];
        if (_isInvisible(child)) continue;

        if (previous != null) {
          _buffer.write(_lineFeed.text);
          if (previous.isGroupEnd) _buffer.write(_lineFeed.text);
        }
        previous = child;

        child.accept(this);
      }
    });
    _buffer.write(_lineFeed.text);
    _writeIndentation();
    _buffer.writeCharCode($rbrace);
  }

  /// Writes indentation based on [_indentation].
  void _writeIndentation() {
    for (var i = 0; i < _indentation * _indentWidth; i++) {
      _buffer.writeCharCode(_indentCharacter);
    }
  }

  /// Calls [callback] to write each value in [iterable], and writes [text] in
  /// between each one.
  void _writeBetween<T>(
      Iterable<T> iterable, String text, void callback(T value)) {
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

  /// Runs [callback] with indentation increased one level.
  void _indent(void callback()) {
    _indentation++;
    callback();
    _indentation--;
  }

  /// Returns whether [node] is considered invisible.
  bool _isInvisible(CssNode node) => !_inspect && node.isInvisible;

  /// Returns whether [text] is a valid identifier.
  bool _isIdentifier(String text) {
    var scanner = new StringScanner(text);
    while (scanner.scanChar($dash)) {}

    if (scanner.isDone) return false;
    var first = scanner.readChar();

    if (isNameStart(first)) {
      if (scanner.isDone) return true;
      scanner.readChar();
    } else if (first == $backslash) {
      if (!_consumeEscape(scanner)) return false;
    } else {
      return false;
    }

    while (true) {
      var next = scanner.peekChar();
      if (next == null) return true;

      if (isName(next)) {
        scanner.readChar();
      } else if (next == $backslash) {
        if (!_consumeEscape(scanner)) return false;
      } else {
        return false;
      }
    }
  }

  /// Consumes an escape sequence in [scanner].
  ///
  /// Returns whether a valid escape was consumed.
  bool _consumeEscape(StringScanner scanner) {
    scanner.expectChar($backslash);

    var first = scanner.peekChar();
    if (first == null || isNewline(first)) return false;

    if (isHex(first)) {
      for (var i = 0; i < 6; i++) {
        var next = scanner.peekChar();
        if (next == null || !isHex(next)) break;
        scanner.readChar();
      }
      if (isWhitespace(scanner.peekChar())) scanner.readChar();
    } else {
      if (scanner.isDone) return false;
      scanner.readChar();
    }

    return true;
  }
}

/// An enum of generated CSS styles.
class OutputStyle {
  /// The standard CSS style, with each declaration on its own line.
  static const expanded = const OutputStyle._("expanded");

  /// The name of the style.
  final String _name;

  const OutputStyle._(this._name);

  String toString() => _name;
}

/// An enum of line feed sequences.
class LineFeed {
  /// A single carriage return.
  static const cr = const LineFeed._('cr', '\r');

  /// A carriage return followed by a line feed.
  static const crlf = const LineFeed._('crlf', '\r\n');

  /// A single line feed.
  static const lf = const LineFeed._('lf', '\n');

  /// A line feed followed by a carriage return.
  static const lfcr = const LineFeed._('lfcr', '\n\r');

  /// The name of this sequence..
  final String name;

  /// The text to emit for this line feed.
  final String text;

  const LineFeed._(this.name, this.text);

  String toString() => name;
}
