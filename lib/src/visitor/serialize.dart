// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:charcode/charcode.dart';
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
import '../util/nullable.dart';
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
    prefix = style == OutputStyle.compressed ? '\uFEFF' : '@charset "UTF-8";\n';
  } else {
    prefix = '';
  }

  return (
    prefix + css,
    sourceMap: sourceMap ? visitor._buffer.buildSourceMap(prefix: prefix) : null
  );
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
final class _SerializeVisitor
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

      // Ignore sourceMappingURL and sourceURL comments.
      if (node.text.startsWith(RegExp(r"/\*# source(Mapping)?URL="))) return;

      if (_minimumIndentation(node.text) case var minimumIndentation?) {
        assert(minimumIndentation != -1);
        minimumIndentation =
            math.min(minimumIndentation, node.span.start.column);

        _writeIndentation();
        _writeWithIndent(node.text, minimumIndentation);
      } else {
        _writeIndentation();
        _buffer.write(node.text);
      }
    });
  }

  void visitCssAtRule(CssAtRule node) {
    _writeIndentation();

    _for(node, () {
      _buffer.writeCharCode($at);
      _write(node.name);

      if (node.value case var value?) {
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

      var firstQuery = node.queries.first;
      if (!_isCompressed ||
          firstQuery.modifier != null ||
          firstQuery.type != null ||
          (firstQuery.conditions.length == 1 &&
              firstQuery.conditions.first.startsWith("(not "))) {
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

      if (node.modifiers case var modifiers?) {
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
    if (query.modifier case var modifier?) {
      _buffer.write(modifier);
      _buffer.writeCharCode($space);
    }

    if (query.type case var type?) {
      _buffer.write(type);
      if (query.conditions.isNotEmpty) _buffer.write(" and ");
    }

    if (query.conditions case [var first] when first.startsWith("(not ")) {
      _buffer.write("not ");
      var condition = query.conditions.first;
      _buffer.write(condition.substring("(not ".length, condition.length - 1));
    } else {
      var operator = query.conjunction ? "and" : "or";
      _writeBetween(query.conditions,
          _isCompressed ? "$operator " : " $operator ", _buffer.write);
    }
  }

  void visitCssStyleRule(CssStyleRule node) {
    _writeIndentation();

    _for(node.selector, () => node.selector.accept(this));
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
            error,
            stackTrace);
      } on SassScriptException catch (error, stackTrace) {
        throwWithTrace(
            SassException(error.message, node.value.span), error, stackTrace);
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
      while (scanner.peekChar().isWhitespace) {
        scanner.readChar();
      }
    }
  }

  /// Emits the value of [node], re-indented relative to the current indentation.
  void _writeReindentedValue(CssDeclaration node) {
    var value = (node.value.value as SassString).text;

    switch (_minimumIndentation(value)) {
      case null:
        _buffer.write(value);
      case -1:
        _buffer.write(trimAsciiRight(value, excludeEscape: true));
        _buffer.writeCharCode($space);
      case var minimumIndentation:
        _writeWithIndent(
            value, math.min(minimumIndentation, node.name.span.start.column));
    }
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
      assert(scanner.peekChar(-1).isWhitespace);

      // Scan forward until we hit non-whitespace or the end of [text].
      var lineStart = scanner.position;
      var newlines = 1;
      inner:
      while (true) {
        // If we hit the end of [text], we still need to preserve the fact that
        // whitespace exists because it could matter for custom properties.
        if (scanner.isDone) {
          _buffer.writeCharCode($space);
          return;
        }

        switch (scanner.readChar()) {
          case $space || $tab:
            continue inner;
          case $lf:
            lineStart = scanner.position;
            newlines++;
          case _:
            break inner;
        }
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
    switch (value) {
      case SassNumber(hasComplexUnits: true) when !_inspect:
        throw SassScriptException("$value isn't a valid CSS value.");

      case SassNumber(value: double(isFinite: false)):
        switch (value.value) {
          case double.infinity:
            _buffer.write('infinity');
          case double.negativeInfinity:
            _buffer.write('-infinity');
          case double(isNaN: true):
            _buffer.write('NaN');
        }

        _writeCalculationUnits(value.numeratorUnits, value.denominatorUnits);

      case SassNumber(hasComplexUnits: true):
        _writeNumber(value.value);
        if (value.numeratorUnits case [var first, ...var rest]) {
          _buffer.write(first);
          _writeCalculationUnits(rest, value.denominatorUnits);
        } else {
          _writeCalculationUnits([], value.denominatorUnits);
        }

      case Value():
        value.accept(this);

      case CalculationOperation(:var operator, :var left, :var right):
        var parenthesizeLeft = left is CalculationOperation &&
            left.operator.precedence < operator.precedence;
        if (parenthesizeLeft) _buffer.writeCharCode($lparen);
        _writeCalculationValue(left);
        if (parenthesizeLeft) _buffer.writeCharCode($rparen);

        var operatorWhitespace = !_isCompressed || operator.precedence == 1;
        if (operatorWhitespace) _buffer.writeCharCode($space);
        _buffer.write(operator.operator);
        if (operatorWhitespace) _buffer.writeCharCode($space);

        var parenthesizeRight = (right is CalculationOperation &&
                _parenthesizeCalculationRhs(operator, right.operator)) ||
            (operator == CalculationOperator.dividedBy &&
                right is SassNumber &&
                (right.value.isFinite
                    ? right.hasComplexUnits
                    : right.hasUnits));
        if (parenthesizeRight) _buffer.writeCharCode($lparen);
        _writeCalculationValue(right);
        if (parenthesizeRight) _buffer.writeCharCode($rparen);
    }
  }

  /// Writes the complex numerator and denominator units beyond the first
  /// numerator unit for a number as they appear in a calculation.
  void _writeCalculationUnits(
      List<String> numeratorUnits, List<String> denominatorUnits) {
    for (var unit in numeratorUnits) {
      _writeOptionalSpace();
      _buffer.writeCharCode($asterisk);
      _writeOptionalSpace();
      _buffer.writeCharCode($1);
      _buffer.write(unit);
    }

    for (var unit in denominatorUnits) {
      _writeOptionalSpace();
      _buffer.writeCharCode($slash);
      _writeOptionalSpace();
      _buffer.writeCharCode($1);
      _buffer.write(unit);
    }
  }

  /// Returns whether the right-hand operation of a calculation should be
  /// parenthesized.
  ///
  /// In `a ? (b # c)`, `outer` is `?` and `right` is `#`.
  bool _parenthesizeCalculationRhs(
          CalculationOperator outer, CalculationOperator right) =>
      switch (outer) {
        CalculationOperator.dividedBy => true,
        CalculationOperator.plus => false,
        _ => right == CalculationOperator.plus ||
            right == CalculationOperator.minus
      };

  void visitColor(SassColor value) {
    switch (value.space) {
      case ColorSpace.rgb || ColorSpace.hsl || ColorSpace.hwb
          when !value.isChannel0Missing &&
              !value.isChannel1Missing &&
              !value.isChannel2Missing &&
              !value.isAlphaMissing:
        _writeLegacyColor(value);

      case ColorSpace.rgb:
        _buffer.write('rgb(');
        _writeChannel(value.channel0OrNull);
        _buffer.writeCharCode($space);
        _writeChannel(value.channel1OrNull);
        _buffer.writeCharCode($space);
        _writeChannel(value.channel2OrNull);
        _maybeWriteSlashAlpha(value);
        _buffer.writeCharCode($rparen);

      case ColorSpace.hsl || ColorSpace.hwb:
        _buffer
          ..write(value.space)
          ..writeCharCode($lparen);
        _writeChannel(value.channel0OrNull);
        if (!_isCompressed && !value.isChannel0Missing) _buffer.write('deg');
        _buffer.writeCharCode($space);
        _writeChannel(value.channel1OrNull);
        if (!value.isChannel1Missing) _buffer.writeCharCode($percent);
        _buffer.writeCharCode($space);
        _writeChannel(value.channel2OrNull);
        if (!value.isChannel2Missing) _buffer.writeCharCode($percent);
        _maybeWriteSlashAlpha(value);
        _buffer.writeCharCode($rparen);

      case ColorSpace.lab ||
            ColorSpace.oklab ||
            ColorSpace.lch ||
            ColorSpace.oklch:
        _buffer
          ..write(value.space)
          ..writeCharCode($lparen);
        if (!_isCompressed && !value.isChannel0Missing) {
          var max = (value.space.channels[0] as LinearChannel).max;
          _writeNumber(value.channel0 * 100 / max);
          _buffer.writeCharCode($percent);
        } else {
          _writeChannel(value.channel0OrNull);
        }
        _buffer.writeCharCode($space);
        _writeChannel(value.channel1OrNull);
        _buffer.writeCharCode($space);
        _writeChannel(value.channel2OrNull);
        if (!_isCompressed &&
            !value.isChannel2Missing &&
            value.space.channels[2].isPolarAngle) {
          _buffer.write('deg');
        }
        _maybeWriteSlashAlpha(value);
        _buffer.writeCharCode($rparen);

      case _:
        _buffer
          ..write('color(')
          ..write(value.space)
          ..writeCharCode($space);
        _writeBetween(value.channelsOrNull, ' ', _writeChannel);
        _maybeWriteSlashAlpha(value);
        _buffer.writeCharCode($rparen);
    }
  }

  /// Writes a [channel] which may be missing.
  void _writeChannel(double? channel) {
    if (channel == null) {
      _buffer.write('none');
    } else {
      _writeNumber(channel);
    }
  }

  /// Writes a legacy color to the stylesheet.
  ///
  /// Unlike newer color spaces, the three legacy color spaces are
  /// interchangeable with one another. We choose the shortest representation
  /// that's still compatible with all the browsers we support.
  void _writeLegacyColor(SassColor color) {
    var opaque = fuzzyEquals(color.alpha, 1);

    // In compressed mode, emit colors in the shortest representation possible.
    if (_isCompressed) {
      var rgb = color.toSpace(ColorSpace.rgb);
      if (opaque && _tryIntegerRgb(rgb)) return;

      var red = _writeNumberToString(rgb.channel0);
      var green = _writeNumberToString(rgb.channel1);
      var blue = _writeNumberToString(rgb.channel2);

      var hsl = color.toSpace(ColorSpace.hsl);
      var hue = _writeNumberToString(hsl.channel0);
      var saturation = _writeNumberToString(hsl.channel1);
      var lightness = _writeNumberToString(hsl.channel2);

      // Add two characters for HSL for the %s on saturation and lightness.
      if (red.length + green.length + blue.length <=
          hue.length + saturation.length + lightness.length + 2) {
        _buffer
          ..write(opaque ? 'rgb(' : 'rgba(')
          ..write(red)
          ..writeCharCode($comma)
          ..write(green)
          ..writeCharCode($comma)
          ..write(blue);
      } else {
        _buffer
          ..write(opaque ? 'hsl(' : 'hsla(')
          ..write(hue)
          ..writeCharCode($comma)
          ..write(saturation)
          ..write('%,')
          ..write(lightness)
          ..writeCharCode($percent);
      }
      if (!opaque) {
        _buffer.writeCharCode($comma);
        _writeNumber(color.alpha);
      }
      _buffer.writeCharCode($rparen);
      return;
    }

    if (color.space == ColorSpace.hsl) {
      _writeHsl(color);
      return;
    }

    switch (color.format) {
      case ColorFormat.rgbFunction:
        _writeRgb(color);
        return;

      case SpanColorFormat format:
        _buffer.write(format.original);
        return;
    }

    // Always emit generated transparent colors in rgba format. This works
    // around an IE bug. See sass/sass#1782.
    if (opaque) {
      var rgb = color.toSpace(ColorSpace.rgb);
      if (namesByColor[rgb] case var name?) {
        _buffer.write(name);
        return;
      }

      if (_canUseHex(rgb)) {
        _buffer.writeCharCode($hash);
        _writeHexComponent(rgb.channel0.round());
        _writeHexComponent(rgb.channel1.round());
        _writeHexComponent(rgb.channel2.round());
        return;
      }
    }

    // If an HWB color can't be represented as a hex color, write is as HSL
    // rather than RGB since that more clearly captures the author's intent.
    if (color.space == ColorSpace.hwb) {
      _writeHsl(color);
    } else {
      _writeRgb(color);
    }
  }

  /// If [value] can be written as a hex code or a color name, writes it in the
  /// shortest format possible and returns `true.`
  ///
  /// Otherwise, writes nothing and returns `false`. Assumes [value] is in the
  /// RGB space.
  bool _tryIntegerRgb(SassColor rgb) {
    assert(rgb.space == ColorSpace.rgb);
    if (!_canUseHex(rgb)) return false;

    var redInt = rgb.channel0.round();
    var greenInt = rgb.channel1.round();
    var blueInt = rgb.channel2.round();

    var shortHex = _canUseShortHex(redInt, greenInt, blueInt);
    if (namesByColor[rgb] case var name?
        when name.length <= (shortHex ? 4 : 7)) {
      _buffer.write(name);
    } else if (shortHex) {
      _buffer.writeCharCode($hash);
      _buffer.writeCharCode(hexCharFor(redInt & 0xF));
      _buffer.writeCharCode(hexCharFor(greenInt & 0xF));
      _buffer.writeCharCode(hexCharFor(blueInt & 0xF));
    } else {
      _buffer.writeCharCode($hash);
      _writeHexComponent(redInt);
      _writeHexComponent(greenInt);
      _writeHexComponent(blueInt);
    }
    return true;
  }

  /// Whether [rgb] can be represented as a hexadecimal color.
  bool _canUseHex(SassColor rgb) {
    assert(rgb.space == ColorSpace.rgb);
    return _canUseHexForChannel(rgb.channel0) &&
        _canUseHexForChannel(rgb.channel1) &&
        _canUseHexForChannel(rgb.channel2);
  }

  /// Whether [channel]'s value can be represented as a two-character
  /// hexadecimal value.
  bool _canUseHexForChannel(double channel) =>
      fuzzyIsInt(channel) &&
      fuzzyGreaterThanOrEquals(channel, 0) &&
      fuzzyLessThan(channel, 256);

  /// Writes [value] as an `rgb()` or `rgba()` function.
  void _writeRgb(SassColor color) {
    var opaque = fuzzyEquals(color.alpha, 1);
    var rgb = color.toSpace(ColorSpace.rgb);
    _buffer.write(opaque ? "rgb(" : "rgba(");
    _writeNumber(rgb.channel('red'));
    _buffer.write(_commaSeparator);
    _writeNumber(rgb.channel('green'));
    _buffer.write(_commaSeparator);
    _writeNumber(rgb.channel('blue'));

    if (!opaque) {
      _buffer.write(_commaSeparator);
      _writeNumber(color.alpha);
    }

    _buffer.writeCharCode($rparen);
  }

  /// Writes [value] as an `hsl()` or `hsla()` function.
  void _writeHsl(SassColor color) {
    var opaque = fuzzyEquals(color.alpha, 1);
    var hsl = color.toSpace(ColorSpace.hsl);
    _buffer.write(opaque ? "hsl(" : "hsla(");
    _writeNumber(hsl.channel('hue'));
    _buffer.write(_commaSeparator);
    _writeNumber(hsl.channel('saturation'));
    _buffer.writeCharCode($percent);
    _buffer.write(_commaSeparator);
    _writeNumber(hsl.channel('lightness'));
    _buffer.writeCharCode($percent);

    if (!opaque) {
      _buffer.write(_commaSeparator);
      _writeNumber(color.alpha);
    }

    _buffer.writeCharCode($rparen);
  }

  /// Returns whether [color]'s hex pair representation is symmetrical (e.g.
  /// `FF`).
  bool _isSymmetricalHex(int color) => color & 0xF == color >> 4;

  /// Returns whether [color] can be represented as a short hexadecimal color
  /// (e.g. `#fff`).
  bool _canUseShortHex(int red, int green, int blue) =>
      _isSymmetricalHex(red) &&
      _isSymmetricalHex(green) &&
      _isSymmetricalHex(blue);

  /// Emits [color] as a hex character pair.
  void _writeHexComponent(int color) {
    assert(color < 0x100);
    _buffer.writeCharCode(hexCharFor(color >> 4));
    _buffer.writeCharCode(hexCharFor(color & 0xF));
  }

  /// Writes the alpha component of [color] if it isn't 1.
  void _maybeWriteSlashAlpha(SassColor color) {
    if (fuzzyEquals(color.alpha, 1)) return;
    _writeOptionalSpace();
    _buffer.writeCharCode($slash);
    _writeOptionalSpace();
    if (color.isAlphaMissing) {
      _buffer.write('none');
    } else {
      _writeNumber(color.alpha);
    }
  }

  void visitFunction(SassFunction function) {
    if (!_inspect) {
      throw SassScriptException("$function isn't a valid CSS value.");
    }

    _buffer.write("get-function(");
    _visitQuotedString(function.callable.name);
    _buffer.writeCharCode($rparen);
  }

  void visitMixin(SassMixin mixin) {
    if (!_inspect) {
      throw SassScriptException("$mixin isn't a valid CSS value.");
    }

    _buffer.write("get-mixin(");
    _visitQuotedString(mixin.callable.name);
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
  String _separatorString(ListSeparator separator) => switch (separator) {
        ListSeparator.comma => _commaSeparator,
        ListSeparator.slash => _isCompressed ? "/" : " / ",
        ListSeparator.space => " ",
        // This should never be used, but it may still be returned since
        // [_separatorString] is invoked eagerly by [writeList] even for lists
        // with only one elements.
        _ => ""
      };

  /// Returns whether [value] needs parentheses as an element in a list with the
  /// given [separator].
  bool _elementNeedsParens(ListSeparator separator, Value value) =>
      switch (value) {
        SassList(asList: List(length: > 1), hasBrackets: false) => switch (
              separator) {
            ListSeparator.comma => value.separator == ListSeparator.comma,
            ListSeparator.slash => value.separator == ListSeparator.comma ||
                value.separator == ListSeparator.slash,
            _ => value.separator != ListSeparator.undecided,
          },
        _ => false
      };

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
    if (value.asSlash case (var before, var after)) {
      visitNumber(before);
      _buffer.writeCharCode($slash);
      visitNumber(after);
      return;
    }

    if (!value.value.isFinite) {
      visitCalculation(SassCalculation.unsimplified('calc', [value]));
      return;
    }

    if (value.hasComplexUnits) {
      if (!_inspect) {
        throw SassScriptException("$value isn't a valid CSS value.");
      }

      visitCalculation(SassCalculation.unsimplified('calc', [value]));
    } else {
      _writeNumber(value.value);
      if (value.numeratorUnits case [var first]) _buffer.write(first);
    }
  }

  /// Like [_writeNumber], but returns a string rather than writing to
  /// [_buffer].
  String _writeNumberToString(double number) {
    var buffer = NoSourceMapBuffer();
    _writeNumber(number, buffer);
    return buffer.toString();
  }

  /// Writes [number] without exponent notation and with at most
  /// [SassNumber.precision] digits after the decimal point.
  ///
  /// The number is written to [buffer], which defaults to [_buffer].
  void _writeNumber(double number, [SourceMapBuffer? buffer]) {
    buffer ??= _buffer;

    // Dart always converts integers to strings in the obvious way, so all we
    // have to do is clamp doubles that are close to being integers.
    if (fuzzyAsInt(number) case var integer?) {
      // JS still uses exponential notation for integers, so we have to handle
      // it here.
      buffer.write(_removeExponent(integer.toString()));
      return;
    }

    var text = _removeExponent(number.toString());

    // Any double that's less than `SassNumber.precision + 2` digits long is
    // guaranteed to be safe to emit directly, since it'll contain at most `0.`
    // followed by [SassNumber.precision] digits.
    var canWriteDirectly = text.length < SassNumber.precision + 2;

    if (canWriteDirectly) {
      if (_isCompressed && text.codeUnitAt(0) == $0) text = text.substring(1);
      buffer.write(text);
      return;
    }

    _writeRounded(text, buffer);
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
  void _writeRounded(String text, SourceMapBuffer buffer) {
    assert(RegExp(r"^-?\d+(\.\d+)?$").hasMatch(text),
        '"$text" should be a number written without exponent notation.');

    // Dart serializes all doubles with a trailing `.0`, even if they have
    // integer values. In that case we definitely don't need to adjust for
    // precision, so we can just write the number as-is without the `.0`.
    if (text.endsWith(".0")) {
      buffer.write(text.substring(0, text.length - 2));
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
        buffer.write(text);
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
      buffer.write(text);
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
      buffer.writeCharCode($0);
      return;
    }

    if (negative) buffer.writeCharCode($minus);

    // Write the digits before the decimal point to [_buffer]. Omit the leading
    // 0 that's added to [digits] to accommodate rounding, and in compressed
    // mode omit the 0 before the decimal point as well.
    var writtenIndex = 0;
    if (digits[0] == 0) {
      writtenIndex++;
      if (_isCompressed && digits[1] == 0) writtenIndex++;
    }
    for (; writtenIndex < firstFractionalDigit; writtenIndex++) {
      buffer.writeCharCode(decimalCharFor(digits[writtenIndex]));
    }

    if (digitsIndex > firstFractionalDigit) {
      buffer.writeCharCode($dot);
      for (; writtenIndex < digitsIndex; writtenIndex++) {
        buffer.writeCharCode(decimalCharFor(digits[writtenIndex]));
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
        case $single_quote when forceDoubleQuote:
          buffer.writeCharCode($single_quote);

        case $single_quote when includesDoubleQuote:
          _visitQuotedString(string, forceDoubleQuote: true);
          return;

        case $single_quote:
          includesSingleQuote = true;
          buffer.writeCharCode($single_quote);

        case $double_quote when forceDoubleQuote:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode($double_quote);

        case $double_quote when includesSingleQuote:
          _visitQuotedString(string, forceDoubleQuote: true);
          return;

        case $double_quote:
          includesDoubleQuote = true;
          buffer.writeCharCode($double_quote);

        // Write newline characters and unprintable ASCII characters as escapes.
        case $nul ||
              $soh ||
              $stx ||
              $etx ||
              $eot ||
              $enq ||
              $ack ||
              $bel ||
              $bs ||
              $lf ||
              $vt ||
              $ff ||
              $cr ||
              $so ||
              $si ||
              $dle ||
              $dc1 ||
              $dc2 ||
              $dc3 ||
              $dc4 ||
              $nak ||
              $syn ||
              $etb ||
              $can ||
              $em ||
              $sub ||
              $esc ||
              $fs ||
              $gs ||
              $rs ||
              $us ||
              $del:
          _writeEscape(buffer, char, string, i);

        case $backslash:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode($backslash);

        case _:
          if (_tryPrivateUseCharacter(buffer, char, string, i)
              case var newIndex?) {
            i = newIndex;
          } else {
            buffer.writeCharCode(char);
          }
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
      switch (string.codeUnitAt(i)) {
        case $lf:
          _buffer.writeCharCode($space);
          afterNewline = true;

        case $space:
          if (!afterNewline) _buffer.writeCharCode($space);

        case var char:
          afterNewline = false;
          if (_tryPrivateUseCharacter(_buffer, char, string, i)
              case var newIndex?) {
            i = newIndex;
          } else {
            _buffer.writeCharCode(char);
          }
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

    if (codeUnit.isPrivateUseBMP) {
      _writeEscape(buffer, codeUnit, string, i);
      return i;
    }

    if (codeUnit.isPrivateUseHighSurrogate && string.length > i + 1) {
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
    if (next case int(isHex: true) || $space || $tab) {
      buffer.writeCharCode($space);
    }
  }

  // ## Selectors

  void visitAttributeSelector(AttributeSelector attribute) {
    _buffer.writeCharCode($lbracket);
    _buffer.write(attribute.name);

    if (attribute.value case var value?) {
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
      attribute.modifier.andThen(_buffer.write);
    }
    _buffer.writeCharCode($rbracket);
  }

  void visitClassSelector(ClassSelector klass) {
    _buffer.writeCharCode($dot);
    _buffer.write(klass.name);
  }

  void visitComplexSelector(ComplexSelector complex) {
    _writeCombinators(complex.leadingCombinators);
    if (complex
        case ComplexSelector(
          leadingCombinators: [_, ...],
          components: [_, ...]
        )) {
      _writeOptionalSpace();
    }

    for (var i = 0; i < complex.components.length; i++) {
      var component = complex.components[i];
      visitCompoundSelector(component.selector);
      if (component.combinators.isNotEmpty) _writeOptionalSpace();
      _writeCombinators(component.combinators);
      if (i != complex.components.length - 1 &&
          (!_isCompressed || component.combinators.isEmpty)) {
        _buffer.writeCharCode($space);
      }
    }
  }

  /// Writes [combinators] to [_buffer], with spaces in between in expanded
  /// mode.
  void _writeCombinators(List<CssValue<Combinator>> combinators) =>
      _writeBetween(combinators, _isCompressed ? '' : ' ', _buffer.write);

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
          _writeIndentation();
        } else {
          _writeOptionalSpace();
        }
      }
      visitComplexSelector(complex);
    }
  }

  void visitParentSelector(ParentSelector parent) {
    _buffer.writeCharCode($ampersand);
    parent.suffix.andThen(_buffer.write);
  }

  void visitPlaceholderSelector(PlaceholderSelector placeholder) {
    _buffer.writeCharCode($percent);
    _buffer.write(placeholder.name);
  }

  void visitPseudoSelector(PseudoSelector pseudo) {
    // `:not(%a)` is semantically identical to `*`.
    if (pseudo
        case PseudoSelector(
          name: 'not',
          selector: SelectorList(isInvisible: true)
        )) {
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
    pseudo.selector.andThen(visitSelectorList);
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

      if (previous.andThen(_requiresSemicolon) ?? false) {
        _buffer.writeCharCode($semicolon);
      }

      if (_isTrailingComment(child, previous ?? parent)) {
        _writeOptionalSpace();
        _withoutIndentation(() => child.accept(this));
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
    if (node.span.sourceUrl != previous.span.sourceUrl) return false;

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
  void _withoutIndentation(void callback()) {
    var savedIndentation = _indentation;
    _indentation = 0;
    callback();
    _indentation = savedIndentation;
  }

  /// Returns whether [node] is considered invisible.
  bool _isInvisible(CssNode node) =>
      !_inspect &&
      (_isCompressed ? node.isInvisibleHidingComments : node.isInvisible);
}

/// An enum of generated CSS styles.
///
/// {@category Compile}
enum OutputStyle {
  /// The standard CSS style, with each declaration on its own line.
  ///
  /// ```css
  /// .sidebar {
  ///   width: 100px;
  /// }
  /// ```
  expanded,

  /// A CSS style that produces as few bytes of output as possible.
  ///
  /// ```css
  /// .sidebar{width:100px}
  /// ```
  compressed;
}

/// An enum of line feed sequences.
enum LineFeed {
  /// A single carriage return.
  cr('cr', '\r'),

  /// A carriage return followed by a line feed.
  crlf('crlf', '\r\n'),

  /// A single line feed.
  lf('lf', '\n'),

  /// A line feed followed by a carriage return.
  lfcr('lfcr', '\n\r');

  /// The name of this sequence..
  final String name;

  /// The text to emit for this line feed.
  final String text;

  const LineFeed(this.name, this.text);

  String toString() => name;
}

/// The result of converting a CSS AST to CSS text.
typedef SerializeResult = (
  /// The serialized CSS.
  String css,

  /// The source map indicating how the source files map to [css].
  ///
  /// This is `null` if source mapping was disabled for this compilation.
  {
  SingleMapping? sourceMap
});
