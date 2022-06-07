// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';
import 'package:source_maps/source_maps.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/css.dart';
import '../ast/node.dart';
import '../ast/selector.dart';
import '../color_names.dart';
import '../exception.dart';
import '../parse/parser.dart';
import '../utils.dart';
import '../util/character.dart';
import '../util/no_source_map_buffer.dart';
import '../util/number.dart';
import '../util/source_map_buffer.dart';
import '../util/span.dart';
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
///
/// If [sourceMap] is `true`, the returned [SerializeResult] will contain a
/// source map indicating how the original Sass files map to the compiled CSS.
///
/// If [charset] is `true`, this will include a `@charset` declaration or a BOM
/// if the stylesheet contains any non-ASCII characters.
SerializeResult serialize(CssNode node,
    {OutputStyle? style,
    bool inspect = false,
    bool useSpaces = true,
    int? indentWidth,
    LineFeed? lineFeed,
    bool sourceMap = false,
    bool charset = true}) {
  indentWidth ??= 2;
  var visitor = _SerializeVisitor(
      style: style,
      inspect: inspect,
      useSpaces: useSpaces,
      indentWidth: indentWidth,
      lineFeed: lineFeed,
      sourceMap: sourceMap);
  node.accept(visitor);
  var css = visitor._buffer.toString();
  String prefix;
  if (charset && css.codeUnits.any((codeUnit) => codeUnit > 0x7F)) {
    if (style == OutputStyle.compressed) {
      prefix = '\uFEFF';
    } else {
      prefix = '@charset "UTF-8";\n';
    }
  } else {
    prefix = '';
  }

  return SerializeResult(prefix + css,
      sourceMap:
          sourceMap ? visitor._buffer.buildSourceMap(prefix: prefix) : null);
}

/// Converts [value] to a CSS string.
///
/// If [inspect] is `true`, this will emit an unambiguous representation of the
/// source structure. Note however that, although this will be valid SCSS, it
/// may not be valid CSS. If [inspect] is `false` and [value] can't be
/// represented in plain CSS, throws a [SassScriptException].
///
/// If [quote] is `false`, quoted strings are emitted without quotes.
String serializeValue(Value value, {bool inspect = false, bool quote = true}) {
  var visitor =
      _SerializeVisitor(inspect: inspect, quote: quote, sourceMap: false);
  value.accept(visitor);
  return visitor._buffer.toString();
}

/// Converts [selector] to a CSS string.
///
/// If [inspect] is `true`, this will emit an unambiguous representation of the
/// source structure. Note however that, although this will be valid SCSS, it
/// may not be valid CSS. If [inspect] is `false` and [selector] can't be
/// represented in plain CSS, throws a [SassScriptException].
String serializeSelector(Selector selector, {bool inspect = false}) {
  var visitor = _SerializeVisitor(inspect: inspect, sourceMap: false);
  selector.accept(visitor);
  return visitor._buffer.toString();
}

/// A visitor that converts CSS syntax trees to plain strings.
class _SerializeVisitor
    implements CssVisitor<void>, ValueVisitor<void>, SelectorVisitor<void> {
  /// A buffer that contains the CSS produced so far.
  final SourceMapBuffer _buffer;

  /// The current indentation of the CSS output.
  var _indentation = 0;

  /// The style of CSS to generate.
  final OutputStyle _style;

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

  /// Whether we're emitting compressed output.
  bool get _isCompressed => _style == OutputStyle.compressed;

  _SerializeVisitor(
      {OutputStyle? style,
      bool inspect = false,
      bool quote = true,
      bool useSpaces = true,
      int? indentWidth,
      LineFeed? lineFeed,
      bool sourceMap = true})
      : _buffer = sourceMap ? SourceMapBuffer() : NoSourceMapBuffer(),
        _style = style ?? OutputStyle.expanded,
        _inspect = inspect,
        _quote = quote,
        _indentCharacter = useSpaces ? $space : $tab,
        _indentWidth = indentWidth ?? 2,
        _lineFeed = lineFeed ?? LineFeed.lf {
    RangeError.checkValueInInterval(_indentWidth, 0, 10, "indentWidth");
  }

  void visitCssStylesheet(CssStylesheet node) {
    CssNode? previous;
    for (var child in node.children) {
      if (_isInvisible(child)) continue;
      if (previous != null) {
        if (_requiresSemicolon(previous)) _buffer.writeCharCode($semicolon);
        if (_isTrailingComment(child, previous)) {
          _writeOptionalSpace();
        } else {
          _writeLineFeed();
          if (previous.isGroupEnd) _writeLineFeed();
        }
      }
      previous = child;

      child.accept(this);
    }

    if (previous != null && _requiresSemicolon(previous) && !_isCompressed) {
      _buffer.writeCharCode($semicolon);
    }
  }

  void visitCssComment(CssComment node) {
    _for(node, () {
      // Preserve comments that start with `/*!`.
      if (_isCompressed && !node.isPreserved) return;

      var minimumIndentation = _minimumIndentation(node.text);
      assert(minimumIndentation != -1);
      if (minimumIndentation == null) {
        _writeIndentation();
        _buffer.write(node.text);
        return;
      }

      minimumIndentation = math.min(minimumIndentation, node.span.start.column);

      _writeIndentation();
      _writeWithIndent(node.text, minimumIndentation);
    });
  }

  void visitCssAtRule(CssAtRule node) {
    _writeIndentation();

    _for(node, () {
      _buffer.writeCharCode($at);
      _write(node.name);

      var value = node.value;
      if (value != null) {
        _buffer.writeCharCode($space);
        _write(value);
      }
    });

    if (!node.isChildless) {
      _writeOptionalSpace();
      _visitChildren(node);
    }
  }

  void visitCssMediaRule(CssMediaRule node) {
    _writeIndentation();

    _for(node, () {
      _buffer.write("@media");

      if (!_isCompressed || !node.queries.first.isCondition) {
        _buffer.writeCharCode($space);
      }

      _writeBetween(node.queries, _commaSeparator, _visitMediaQuery);
    });

    _writeOptionalSpace();
    _visitChildren(node);
  }

  void visitCssImport(CssImport node) {
    _writeIndentation();

    _for(node, () {
      _buffer.write("@import");
      _writeOptionalSpace();
      _for(node.url, () => _writeImportUrl(node.url.value));

      var modifiers = node.modifiers;
      if (modifiers != null) {
        _writeOptionalSpace();
        _buffer.write(modifiers);
      }
    });
  }

  /// Writes [url], which is an import's URL, to the buffer.
  void _writeImportUrl(String url) {
    if (!_isCompressed || url.codeUnitAt(0) != $u) {
      _buffer.write(url);
      return;
    }

    // If this is url(...), remove the surrounding function. This is terser and
    // it allows us to remove whitespace between `@import` and the URL.
    var urlContents = url.substring(4, url.length - 1);

    var maybeQuote = urlContents.codeUnitAt(0);
    if (maybeQuote == $single_quote || maybeQuote == $double_quote) {
      _buffer.write(urlContents);
    } else {
      // If the URL didn't contain quotes, write them manually.
      _visitQuotedString(urlContents);
    }
  }

  void visitCssKeyframeBlock(CssKeyframeBlock node) {
    _writeIndentation();

    _for(
        node.selector,
        () =>
            _writeBetween(node.selector.value, _commaSeparator, _buffer.write));
    _writeOptionalSpace();
    _visitChildren(node);
  }

  void _visitMediaQuery(CssMediaQuery query) {
    if (query.modifier != null) {
      _buffer.write(query.modifier);
      _buffer.writeCharCode($space);
    }

    if (query.type != null) {
      _buffer.write(query.type);
      if (query.features.isNotEmpty) {
        _buffer.write(" and ");
      }
    }

    _writeBetween(
        query.features, _isCompressed ? "and " : " and ", _buffer.write);
  }

  void visitCssStyleRule(CssStyleRule node) {
    _writeIndentation();

    _for(node.selector, () => node.selector.value.accept(this));
    _writeOptionalSpace();
    _visitChildren(node);
  }

  void visitCssSupportsRule(CssSupportsRule node) {
    _writeIndentation();

    _for(node, () {
      _buffer.write("@supports");

      if (!(_isCompressed && node.condition.value.codeUnitAt(0) == $lparen)) {
        _buffer.writeCharCode($space);
      }

      _write(node.condition);
    });

    _writeOptionalSpace();
    _visitChildren(node);
  }

  void visitCssDeclaration(CssDeclaration node) {
    _writeIndentation();

    _write(node.name);
    _buffer.writeCharCode($colon);

    // If `node` is a custom property that was parsed as a normal Sass-syntax
    // property (such as `#{--foo}: ...`), we serialize its value using the
    // normal Sass property logic as well.
    if (node.isCustomProperty && node.parsedAsCustomProperty) {
      _for(node.value, () {
        if (_isCompressed) {
          _writeFoldedValue(node);
        } else {
          _writeReindentedValue(node);
        }
      });
    } else {
      _writeOptionalSpace();
      try {
        _buffer.forSpan(
            node.valueSpanForMap, () => node.value.value.accept(this));
      } on MultiSpanSassScriptException catch (error, stackTrace) {
        throwWithTrace(
            MultiSpanSassException(error.message, node.value.span,
                error.primaryLabel, error.secondarySpans),
            stackTrace);
      } on SassScriptException catch (error, stackTrace) {
        throwWithTrace(
            SassException(error.message, node.value.span), stackTrace);
      }
    }
  }

  /// Emits the value of [node], with all newlines followed by whitespace
  void _writeFoldedValue(CssDeclaration node) {
    var scanner = StringScanner((node.value.value as SassString).text);
    while (!scanner.isDone) {
      var next = scanner.readChar();
      if (next != $lf) {
        _buffer.writeCharCode(next);
        continue;
      }

      _buffer.writeCharCode($space);
      while (isWhitespace(scanner.peekChar())) {
        scanner.readChar();
      }
    }
  }

  /// Emits the value of [node], re-indented relative to the current indentation.
  void _writeReindentedValue(CssDeclaration node) {
    var value = (node.value.value as SassString).text;

    var minimumIndentation = _minimumIndentation(value);
    if (minimumIndentation == null) {
      _buffer.write(value);
      return;
    } else if (minimumIndentation == -1) {
      _buffer.write(trimAsciiRight(value, excludeEscape: true));
      _buffer.writeCharCode($space);
      return;
    }

    minimumIndentation =
        math.min(minimumIndentation, node.name.span.start.column);
    _writeWithIndent(value, minimumIndentation);
  }

  /// Returns the indentation level of the least-indented non-empty line in
  /// [text] after the first.
  ///
  /// Returns `null` if [text] contains no newlines, and -1 if it contains
  /// newlines but no lines are indented.
  int? _minimumIndentation(String text) {
    var scanner = LineScanner(text);
    while (!scanner.isDone && scanner.readChar() != $lf) {}
    if (scanner.isDone) return scanner.peekChar(-1) == $lf ? -1 : null;

    int? min;
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

    return min ?? -1;
  }

  /// Writes [text] to [_buffer], replacing [minimumIndentation] with
  /// [_indentation] for each non-empty line after the first.
  ///
  /// Compresses trailing empty lines of [text] into a single trailing space.
  void _writeWithIndent(String text, int minimumIndentation) {
    var scanner = LineScanner(text);

    // Write the first line as-is.
    while (!scanner.isDone) {
      var next = scanner.readChar();
      if (next == $lf) break;
      _buffer.writeCharCode(next);
    }

    while (true) {
      assert(isWhitespace(scanner.peekChar(-1)));

      // Scan forward until we hit non-whitespace or the end of [text].
      var lineStart = scanner.position;
      var newlines = 1;
      while (true) {
        // If we hit the end of [text], we still need to preserve the fact that
        // whitespace exists because it could matter for custom properties.
        if (scanner.isDone) {
          _buffer.writeCharCode($space);
          return;
        }

        var next = scanner.readChar();
        if (next == $space || next == $tab) continue;
        if (next != $lf) break;
        lineStart = scanner.position;
        newlines++;
      }

      _writeTimes($lf, newlines);
      _writeIndentation();
      _buffer.write(scanner.substring(lineStart + minimumIndentation));

      // Scan and write until we hit a newline or the end of [text].
      while (true) {
        if (scanner.isDone) return;
        var next = scanner.readChar();
        if (next == $lf) break;
        _buffer.writeCharCode(next);
      }
    }
  }

  // ## Values

  void visitBoolean(SassBoolean value) => _buffer.write(value.value.toString());

  void visitCalculation(SassCalculation value) {
    _buffer.write(value.name);
    _buffer.writeCharCode($lparen);
    _writeBetween(value.arguments, _commaSeparator, _writeCalculationValue);
    _buffer.writeCharCode($rparen);
  }

  void _writeCalculationValue(Object value) {
    if (value is Value) {
      value.accept(this);
    } else if (value is CalculationInterpolation) {
      _buffer.write(value.value);
    } else if (value is CalculationOperation) {
      var left = value.left;
      var parenthesizeLeft = left is CalculationInterpolation ||
          (left is CalculationOperation &&
              left.operator.precedence < value.operator.precedence);
      if (parenthesizeLeft) _buffer.writeCharCode($lparen);
      _writeCalculationValue(left);
      if (parenthesizeLeft) _buffer.writeCharCode($rparen);

      var operatorWhitespace = !_isCompressed || value.operator.precedence == 1;
      if (operatorWhitespace) _buffer.writeCharCode($space);
      _buffer.write(value.operator.operator);
      if (operatorWhitespace) _buffer.writeCharCode($space);

      var right = value.right;
      var parenthesizeRight = right is CalculationInterpolation ||
          (right is CalculationOperation &&
              _parenthesizeCalculationRhs(value.operator, right.operator));
      if (parenthesizeRight) _buffer.writeCharCode($lparen);
      _writeCalculationValue(right);
      if (parenthesizeRight) _buffer.writeCharCode($rparen);
    }
  }

  /// Returns whether the right-hand operation of a calculation should be
  /// parenthesized.
  ///
  /// In `a ? (b # c)`, `outer` is `?` and `right` is `#`.
  bool _parenthesizeCalculationRhs(
      CalculationOperator outer, CalculationOperator right) {
    if (outer == CalculationOperator.dividedBy) return true;
    if (outer == CalculationOperator.plus) return false;
    return right == CalculationOperator.plus ||
        right == CalculationOperator.minus;
  }

  void visitColor(SassColor value) {
    // In compressed mode, emit colors in the shortest representation possible.
    if (_isCompressed) {
      if (!fuzzyEquals(value.alpha, 1)) {
        _writeRgb(value);
      } else {
        var name = namesByColor[value];
        var hexLength = _canUseShortHex(value) ? 4 : 7;
        if (name != null && name.length <= hexLength) {
          _buffer.write(name);
        } else if (_canUseShortHex(value)) {
          _buffer.writeCharCode($hash);
          _buffer.writeCharCode(hexCharFor(value.red & 0xF));
          _buffer.writeCharCode(hexCharFor(value.green & 0xF));
          _buffer.writeCharCode(hexCharFor(value.blue & 0xF));
        } else {
          _buffer.writeCharCode($hash);
          _writeHexComponent(value.red);
          _writeHexComponent(value.green);
          _writeHexComponent(value.blue);
        }
      }
    } else {
      var format = value.format;
      if (format != null) {
        if (format == ColorFormat.rgbFunction) {
          _writeRgb(value);
        } else if (format == ColorFormat.hslFunction) {
          _writeHsl(value);
        } else {
          _buffer.write((format as SpanColorFormat).original);
        }
      } else if (namesByColor.containsKey(value) &&
          // Always emit generated transparent colors in rgba format. This works
          // around an IE bug. See sass/sass#1782.
          !fuzzyEquals(value.alpha, 0)) {
        _buffer.write(namesByColor[value]);
      } else if (fuzzyEquals(value.alpha, 1)) {
        _buffer.writeCharCode($hash);
        _writeHexComponent(value.red);
        _writeHexComponent(value.green);
        _writeHexComponent(value.blue);
      } else {
        _writeRgb(value);
      }
    }
  }

  /// Writes [value] as an `rgb()` or `rgba()` function.
  void _writeRgb(SassColor value) {
    var opaque = fuzzyEquals(value.alpha, 1);
    _buffer
      ..write(opaque ? "rgb(" : "rgba(")
      ..write(value.red)
      ..write(_commaSeparator)
      ..write(value.green)
      ..write(_commaSeparator)
      ..write(value.blue);

    if (!opaque) {
      _buffer.write(_commaSeparator);
      _writeNumber(value.alpha);
    }

    _buffer.writeCharCode($rparen);
  }

  /// Writes [value] as an `hsl()` or `hsla()` function.
  void _writeHsl(SassColor value) {
    var opaque = fuzzyEquals(value.alpha, 1);
    _buffer.write(opaque ? "hsl(" : "hsla(");
    _writeNumber(value.hue);
    _buffer.write("deg");
    _buffer.write(_commaSeparator);
    _writeNumber(value.saturation);
    _buffer.writeCharCode($percent);
    _buffer.write(_commaSeparator);
    _writeNumber(value.lightness);
    _buffer.writeCharCode($percent);

    if (!opaque) {
      _buffer.write(_commaSeparator);
      _writeNumber(value.alpha);
    }

    _buffer.writeCharCode($rparen);
  }

  /// Returns whether [color]'s hex pair representation is symmetrical (e.g.
  /// `FF`).
  bool _isSymmetricalHex(int color) => color & 0xF == color >> 4;

  /// Returns whether [color] can be represented as a short hexadecimal color
  /// (e.g. `#fff`).
  bool _canUseShortHex(SassColor color) =>
      _isSymmetricalHex(color.red) &&
      _isSymmetricalHex(color.green) &&
      _isSymmetricalHex(color.blue);

  /// Emits [color] as a hex character pair.
  void _writeHexComponent(int color) {
    assert(color < 0x100);
    _buffer.writeCharCode(hexCharFor(color >> 4));
    _buffer.writeCharCode(hexCharFor(color & 0xF));
  }

  void visitFunction(SassFunction function) {
    if (!_inspect) {
      throw SassScriptException("$function isn't a valid CSS value.");
    }

    _buffer.write("get-function(");
    _visitQuotedString(function.callable.name);
    _buffer.writeCharCode($rparen);
  }

  void visitList(SassList value) {
    if (value.hasBrackets) {
      _buffer.writeCharCode($lbracket);
    } else if (value.asList.isEmpty) {
      if (!_inspect) {
        throw SassScriptException("() isn't a valid CSS value.");
      }
      _buffer.write("()");
      return;
    }

    var singleton = _inspect &&
        value.asList.length == 1 &&
        (value.separator == ListSeparator.comma ||
            value.separator == ListSeparator.slash);
    if (singleton && !value.hasBrackets) _buffer.writeCharCode($lparen);

    _writeBetween<Value>(
        _inspect
            ? value.asList
            : value.asList.where((element) => !element.isBlank),
        _separatorString(value.separator),
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
      _buffer.write(value.separator.separator);
      if (!value.hasBrackets) _buffer.writeCharCode($rparen);
    }

    if (value.hasBrackets) _buffer.writeCharCode($rbracket);
  }

  /// Returns the string to use to separate list items for lists with the given [separator].
  String _separatorString(ListSeparator separator) {
    switch (separator) {
      case ListSeparator.comma:
        return _commaSeparator;
      case ListSeparator.slash:
        return _isCompressed ? "/" : " / ";
      case ListSeparator.space:
        return " ";
      default:
        // This should never be used, but it may still be returned since
        // [_separatorString] is invoked eagerly by [writeList] even for lists
        // with only one elements.
        return "";
    }
  }

  /// Returns whether [value] needs parentheses as an element in a list with the
  /// given [separator].
  bool _elementNeedsParens(ListSeparator separator, Value value) {
    if (value is SassList) {
      if (value.asList.length < 2) return false;
      if (value.hasBrackets) return false;
      switch (separator) {
        case ListSeparator.comma:
          return value.separator == ListSeparator.comma;
        case ListSeparator.slash:
          return value.separator == ListSeparator.comma ||
              value.separator == ListSeparator.slash;
        default:
          return value.separator != ListSeparator.undecided;
      }
    }
    return false;
  }

  void visitMap(SassMap map) {
    if (!_inspect) {
      throw SassScriptException("$map isn't a valid CSS value.");
    }
    _buffer.writeCharCode($lparen);
    _writeBetween<MapEntry<Value, Value>>(map.contents.entries, ", ", (entry) {
      _writeMapElement(entry.key);
      _buffer.write(": ");
      _writeMapElement(entry.value);
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

  void visitNull() {
    if (_inspect) _buffer.write("null");
  }

  void visitNumber(SassNumber value) {
    var asSlash = value.asSlash;
    if (asSlash != null) {
      visitNumber(asSlash.item1);
      _buffer.writeCharCode($slash);
      visitNumber(asSlash.item2);
      return;
    }

    _writeNumber(value.value);

    if (!_inspect) {
      if (value.numeratorUnits.length > 1 ||
          value.denominatorUnits.isNotEmpty) {
        throw SassScriptException("$value isn't a valid CSS value.");
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
      // Node.js still uses exponential notation for integers, so we have to
      // handle it here.
      _buffer.write(_removeExponent(integer.toString()));
      return;
    }

    var text = _removeExponent(number.toString());

    // Any double that's less than `SassNumber.precision + 2` digits long is
    // guaranteed to be safe to emit directly, since it'll contain at most `0.`
    // followed by [SassNumber.precision] digits.
    var canWriteDirectly = text.length < SassNumber.precision + 2;

    if (canWriteDirectly) {
      if (_isCompressed && text.codeUnitAt(0) == $0) text = text.substring(1);
      _buffer.write(text);
      return;
    }

    _writeRounded(text);
  }

  /// If [text] is written in exponent notation, returns a string representation
  /// of it without exponent notation.
  ///
  /// Otherwise, returns [text] as-is.
  String _removeExponent(String text) {
    // Don't allocate this until we know [text] contains exponent notation.
    StringBuffer? buffer;
    var negative = text.codeUnitAt(0) == $minus;

    late int exponent;
    for (var i = 0; i < text.length; i++) {
      var codeUnit = text.codeUnitAt(i);
      if (codeUnit != $e) continue;

      buffer = StringBuffer();
      buffer.writeCharCode(text.codeUnitAt(0));

      // If the number has more than one significant digit, the second
      // character will be a decimal point that we don't want to include in
      // the generated number.
      if (negative) {
        buffer.writeCharCode(text.codeUnitAt(1));
        if (i > 3) buffer.write(text.substring(3, i));
      } else {
        if (i > 2) buffer.write(text.substring(2, i));
      }

      exponent = int.parse(text.substring(i + 1, text.length));
      break;
    }
    if (buffer == null) return text;

    if (exponent > 0) {
      // Write an additional zero for each exponent digits other than those
      // already written to the buffer. We subtract 1 from `buffer.length`
      // because the first digit doesn't count towards the exponent. Subtract 1
      // more for negative numbers because of the `-` written to the buffer.
      var additionalZeroes =
          exponent - (buffer.length - 1 - (negative ? 1 : 0));

      for (var i = 0; i < additionalZeroes; i++) {
        buffer.writeCharCode($0);
      }
      return buffer.toString();
    } else {
      var result = StringBuffer();
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

  /// Assuming [text] is a number written without exponent notation, rounds it
  /// to [SassNumber.precision] digits after the decimal and writes the result
  /// to [_buffer].
  void _writeRounded(String text) {
    assert(RegExp(r"^-?\d+(\.\d+)?$").hasMatch(text),
        '"$text" should be a number written without exponent notation.');

    // Dart serializes all doubles with a trailing `.0`, even if they have
    // integer values. In that case we definitely don't need to adjust for
    // precision, so we can just write the number as-is without the `.0`.
    if (text.endsWith(".0")) {
      _buffer.write(text.substring(0, text.length - 2));
      return;
    }

    // We need to ensure that we write at most [SassNumber.precision] digits
    // after the decimal point, and that we round appropriately if necessary. To
    // do this, we maintain an intermediate buffer of digits (both before and
    // after the decimal point), which we then write to [_buffer] as text. We
    // start writing after the first digit to give us room to round up to a
    // higher decimal place than was represented in the original number.
    var digits = Uint8List(text.length + 1);
    var digitsIndex = 1;

    // Write the digits before the decimal to [digits].
    var textIndex = 0;
    var negative = text.codeUnitAt(0) == $minus;
    if (negative) textIndex++;
    while (true) {
      if (textIndex == text.length) {
        // If we get here, [text] has no decmial point. It definitely doesn't
        // need to be rounded; we can write it as-is.
        _buffer.write(text);
        return;
      }

      var codeUnit = text.codeUnitAt(textIndex++);
      if (codeUnit == $dot) break;
      digits[digitsIndex++] = asDecimal(codeUnit);
    }
    var firstFractionalDigit = digitsIndex;

    // Only write at most [precision] digits after the decimal. If there aren't
    // that many digits left in the number, write it as-is since no rounding or
    // truncation is needed.
    var indexAfterPrecision = textIndex + SassNumber.precision;
    if (indexAfterPrecision >= text.length) {
      _buffer.write(text);
      return;
    }

    // Write the digits after the decimal to [digits].
    while (textIndex < indexAfterPrecision) {
      digits[digitsIndex++] = asDecimal(text.codeUnitAt(textIndex++));
    }

    // Round the trailing digits in [digits] up if necessary.
    if (asDecimal(text.codeUnitAt(textIndex)) >= 5) {
      while (true) {
        // [digitsIndex] is guaranteed to be >0 here because we added a leading
        // 0 to [digits] when we constructed it, so even if we round everything
        // up [newDigit] will always be 1 when digitsIndex is 1.
        var newDigit = ++digits[digitsIndex - 1];
        if (newDigit != 10) break;
        digitsIndex--;
      }
    }

    // At most one of the following loops will actually execute. If we rounded
    // digits up before the decimal point, the first loop will set those digits
    // to 0 (rather than 10, which is not a valid decimal digit). On the other
    // hand, if we have trailing zeros left after the decimal point, the second
    // loop will move [digitsIndex] before them and cause them not to be
    // written. Either way, [digitsIndex] will end up >= [firstFractionalDigit].
    for (; digitsIndex < firstFractionalDigit; digitsIndex++) {
      digits[digitsIndex] = 0;
    }
    while (digitsIndex > firstFractionalDigit && digits[digitsIndex - 1] == 0) {
      digitsIndex--;
    }

    // Omit the minus sign if the number ended up being rounded to exactly zero,
    // write "0" explicit to avoid adding a minus sign or omitting the number
    // entirely in compressed mode.
    if (digitsIndex == 2 && digits[0] == 0 && digits[1] == 0) {
      _buffer.writeCharCode($0);
      return;
    }

    if (negative) _buffer.writeCharCode($minus);

    // Write the digits before the decimal point to [_buffer]. Omit the leading
    // 0 that's added to [digits] to accommodate rounding, and in compressed
    // mode omit the 0 before the decimal point as well.
    var writtenIndex = 0;
    if (digits[0] == 0) {
      writtenIndex++;
      if (_isCompressed && digits[1] == 0) writtenIndex++;
    }
    for (; writtenIndex < firstFractionalDigit; writtenIndex++) {
      _buffer.writeCharCode(decimalCharFor(digits[writtenIndex]));
    }

    if (digitsIndex > firstFractionalDigit) {
      _buffer.writeCharCode($dot);
      for (; writtenIndex < digitsIndex; writtenIndex++) {
        _buffer.writeCharCode(decimalCharFor(digits[writtenIndex]));
      }
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
  void _visitQuotedString(String string, {bool forceDoubleQuote = false}) {
    var includesSingleQuote = false;
    var includesDoubleQuote = false;

    var buffer = forceDoubleQuote ? _buffer : StringBuffer();
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
          _writeEscape(buffer, char, string, i);
          break;

        case $backslash:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode($backslash);
          break;

        default:
          var newIndex = _tryPrivateUseCharacter(buffer, char, string, i);
          if (newIndex != null) {
            i = newIndex;
            break;
          }

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
          afterNewline = false;
          var newIndex = _tryPrivateUseCharacter(_buffer, char, string, i);
          if (newIndex != null) {
            i = newIndex;
            break;
          }

          _buffer.writeCharCode(char);
          break;
      }
    }
  }

  /// If [codeUnit] is (the beginning of) a private-use character and Sass isn't
  /// emitting compressed CSS, writes that character as an escape to [buffer].
  ///
  /// The [string] is the string from which [codeUnit] was read, and [i] is the
  /// index it was read from. If this successfully writes the character, returns
  /// the index of the *last* code unit that was consumed for it. Otherwise,
  /// returns `null`.
  ///
  /// In expanded mode, we print all characters in Private Use Areas as escape
  /// codes since there's no useful way to render them directly. These
  /// characters are often used for glyph fonts, where it's useful for readers
  /// to be able to distinguish between them in the rendered stylesheet.
  int? _tryPrivateUseCharacter(
      StringBuffer buffer, int codeUnit, String string, int i) {
    if (_isCompressed) return null;

    if (isPrivateUseBMP(codeUnit)) {
      _writeEscape(buffer, codeUnit, string, i);
      return i;
    }

    if (isPrivateUseHighSurrogate(codeUnit) && string.length > i + 1) {
      _writeEscape(buffer,
          combineSurrogates(codeUnit, string.codeUnitAt(i + 1)), string, i + 1);
      return i + 1;
    }

    return null;
  }

  /// Writes [character] as a hexadecimal escape sequence to [buffer].
  ///
  /// The [string] is the string from which the escape is being written, and [i]
  /// is the index of the last code unit of [character] in that string. These
  /// are used to write a trailing space after the escape if necessary to
  /// disambiguate it from the next character.
  void _writeEscape(StringBuffer buffer, int character, String string, int i) {
    buffer.writeCharCode($backslash);
    buffer.write(character.toRadixString(16));

    if (string.length == i + 1) return;
    var next = string.codeUnitAt(i + 1);
    if (isHex(next) || next == $space || next == $tab) {
      buffer.writeCharCode($space);
    }
  }

  // ## Selectors

  void visitAttributeSelector(AttributeSelector attribute) {
    _buffer.writeCharCode($lbracket);
    _buffer.write(attribute.name);

    var value = attribute.value;
    if (value != null) {
      _buffer.write(attribute.op);
      if (Parser.isIdentifier(value) &&
          // Emit identifiers that start with `--` with quotes, because IE11
          // doesn't consider them to be valid identifiers.
          !value.startsWith('--')) {
        _buffer.write(value);

        if (attribute.modifier != null) _buffer.writeCharCode($space);
      } else {
        _visitQuotedString(value);
        if (attribute.modifier != null) _writeOptionalSpace();
      }
      if (attribute.modifier != null) _buffer.write(attribute.modifier);
    }
    _buffer.writeCharCode($rbracket);
  }

  void visitClassSelector(ClassSelector klass) {
    _buffer.writeCharCode($dot);
    _buffer.write(klass.name);
  }

  void visitComplexSelector(ComplexSelector complex) {
    ComplexSelectorComponent? lastComponent;
    for (var component in complex.components) {
      if (lastComponent != null &&
          !_omitSpacesAround(lastComponent) &&
          !_omitSpacesAround(component)) {
        _buffer.write(" ");
      }
      if (component is CompoundSelector) {
        visitCompoundSelector(component);
      } else {
        _buffer.write(component);
      }
      lastComponent = component;
    }
  }

  /// When [_style] is [OutputStyle.compressed], omit spaces around combinators.
  bool _omitSpacesAround(ComplexSelectorComponent component) {
    return _isCompressed && component is Combinator;
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
          _writeLineFeed();
        } else {
          _writeOptionalSpace();
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
    var innerSelector = pseudo.selector;
    // `:not(%a)` is semantically identical to `*`.
    if (innerSelector != null &&
        pseudo.name == 'not' &&
        innerSelector.isInvisible) {
      return;
    }

    _buffer.writeCharCode($colon);
    if (pseudo.isSyntacticElement) _buffer.writeCharCode($colon);
    _buffer.write(pseudo.name);
    if (pseudo.argument == null && pseudo.selector == null) return;

    _buffer.writeCharCode($lparen);
    if (pseudo.argument != null) {
      _buffer.write(pseudo.argument);
      if (pseudo.selector != null) _buffer.writeCharCode($space);
    }
    if (innerSelector != null) visitSelectorList(innerSelector);
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

  /// Runs [callback] and associates all text written within it with
  /// [node.span].
  T _for<T>(AstNode node, T callback()) => _buffer.forSpan(node.span, callback);

  /// Writes [value]'s value with the associated source span.
  void _write(CssValue<String> value) =>
      _for(value, () => _buffer.write(value.value));

  /// Emits [parent.children] in a block.
  void _visitChildren(CssParentNode parent) {
    _buffer.writeCharCode($lbrace);

    CssNode? prePrevious;
    CssNode? previous;
    for (var child in parent.children) {
      if (_isInvisible(child)) continue;

      if (previous != null && _requiresSemicolon(previous)) {
        _buffer.writeCharCode($semicolon);
      }

      if (_isTrailingComment(child, previous ?? parent)) {
        _writeOptionalSpace();
        _withoutIndendation(() => child.accept(this));
      } else {
        _writeLineFeed();
        _indent(() {
          child.accept(this);
        });
      }

      prePrevious = previous;
      previous = child;
    }

    if (previous != null) {
      if (_requiresSemicolon(previous) && !_isCompressed) {
        _buffer.writeCharCode($semicolon);
      }

      if (prePrevious == null && _isTrailingComment(previous, parent)) {
        _writeOptionalSpace();
      } else {
        _writeLineFeed();
        _writeIndentation();
      }
    }

    _buffer.writeCharCode($rbrace);
  }

  /// Whether [node] requires a semicolon to be written after it.
  bool _requiresSemicolon(CssNode node) =>
      node is CssParentNode ? node.isChildless : node is! CssComment;

  /// Whether [node] represents a trailing comment when it appears after
  /// [previous] in a sequence of nodes being serialized.
  ///
  /// Note [previous] could be either a sibling of [node] or the parent of
  /// [node], with [node] being the first visible child.
  bool _isTrailingComment(CssNode node, CssNode previous) {
    // Short-circuit in compressed mode to avoid expensive span shenanigans
    // (shespanigans?), since we're compressing all whitespace anyway.
    if (_isCompressed) return false;
    if (node is! CssComment) return false;

    if (!previous.span.contains(node.span)) {
      return node.span.start.line == previous.span.end.line;
    }

    // Walk back from just before the current node starts looking for the
    // parent's left brace (to open the child block). This is safer than a
    // simple forward search of the previous.span.text as that might contain
    // other left braces.
    var searchFrom = node.span.start.offset - previous.span.start.offset - 1;

    // Imports can cause a node to be "contained" by another node when they are
    // actually the same node twice in a row.
    if (searchFrom < 0) return false;

    var endOffset = previous.span.text.lastIndexOf("{", searchFrom);
    endOffset = math.max(0, endOffset);
    var span = previous.span.file.span(
        previous.span.start.offset, previous.span.start.offset + endOffset);
    return node.span.start.line == span.end.line;
  }

  /// Writes a line feed, unless this emitting compressed CSS.
  void _writeLineFeed() {
    if (!_isCompressed) _buffer.write(_lineFeed.text);
  }

  /// Writes a space unless [_style] is [OutputStyle.compressed].
  void _writeOptionalSpace() {
    if (!_isCompressed) _buffer.writeCharCode($space);
  }

  /// Writes indentation based on [_indentation].
  void _writeIndentation() {
    if (_isCompressed) return;
    _writeTimes(_indentCharacter, _indentation * _indentWidth);
  }

  /// Writes [char] to [_buffer] with [times] repetitions.
  void _writeTimes(int char, int times) {
    for (var i = 0; i < times; i++) {
      _buffer.writeCharCode(char);
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

  /// Returns a comma used to separate values in lists.
  String get _commaSeparator => _isCompressed ? "," : ", ";

  /// Runs [callback] with indentation increased one level.
  void _indent(void callback()) {
    _indentation++;
    callback();
    _indentation--;
  }

  /// Runs [callback] without any indentation.
  void _withoutIndendation(void callback()) {
    var savedIndentation = _indentation;
    _indentation = 0;
    callback();
    _indentation = savedIndentation;
  }

  /// Returns whether [node] is considered invisible.
  bool _isInvisible(CssNode node) {
    if (_inspect) return false;
    if (_isCompressed && node is CssComment && !node.isPreserved) return true;
    if (node is CssParentNode) {
      // An unknown at-rule is never invisible. Because we don't know the
      // semantics of unknown rules, we can't guarantee that (for example)
      // `@foo {}` isn't meaningful.
      if (node is CssAtRule) return false;

      if (node is CssStyleRule && node.selector.value.isInvisible) return true;
      return node.children.every(_isInvisible);
    } else {
      return false;
    }
  }
}

/// An enum of generated CSS styles.
///
/// {@category Compile}
@sealed
class OutputStyle {
  /// The standard CSS style, with each declaration on its own line.
  ///
  /// ```css
  /// .sidebar {
  ///   width: 100px;
  /// }
  /// ```
  static const expanded = OutputStyle._("expanded");

  /// A CSS style that produces as few bytes of output as possible.
  ///
  /// ```css
  /// .sidebar{width:100px}
  /// ```
  static const compressed = OutputStyle._("compressed");

  /// The name of the style.
  final String _name;

  const OutputStyle._(this._name);

  String toString() => _name;
}

/// An enum of line feed sequences.
class LineFeed {
  /// A single carriage return.
  static const cr = LineFeed._('cr', '\r');

  /// A carriage return followed by a line feed.
  static const crlf = LineFeed._('crlf', '\r\n');

  /// A single line feed.
  static const lf = LineFeed._('lf', '\n');

  /// A line feed followed by a carriage return.
  static const lfcr = LineFeed._('lfcr', '\n\r');

  /// The name of this sequence..
  final String name;

  /// The text to emit for this line feed.
  final String text;

  const LineFeed._(this.name, this.text);

  String toString() => name;
}

/// The result of converting a CSS AST to CSS text.
class SerializeResult {
  /// The serialized CSS.
  final String css;

  /// The source map indicating how the source files map to [css].
  ///
  /// This is `null` if source mapping was disabled for this compilation.
  final SingleMapping? sourceMap;

  SerializeResult(this.css, {this.sourceMap});
}
