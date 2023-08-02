// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../interpolation_buffer.dart';
// dart-lang/sdk#52535
// ignore: unused_import
import '../../../util/character.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../interpolation.dart';

/// A string literal.
///
/// {@category AST}
final class StringExpression implements Expression {
  /// Interpolation that, when evaluated, produces the contents of this string.
  ///
  /// Unlike [asInterpolation], escapes are resolved and quotes are not
  /// included.
  final Interpolation text;

  /// Whether [this] has quotes.
  final bool hasQuotes;

  FileSpan get span => text.span;

  /// Returns Sass source for a quoted string that, when evaluated, will have
  /// [text] as its contents.
  static String quoteText(String text) {
    var quote = _bestQuote([text]);
    var buffer = StringBuffer();
    buffer.writeCharCode(quote);
    _quoteInnerText(text, quote, buffer, static: true);
    buffer.writeCharCode(quote);
    return buffer.toString();
  }

  StringExpression(this.text, {bool quotes = false}) : hasQuotes = quotes;

  /// Returns a string expression with no interpolation.
  StringExpression.plain(String text, FileSpan span, {bool quotes = false})
      : text = Interpolation([text], span),
        hasQuotes = quotes;

  T accept<T>(ExpressionVisitor<T> visitor) =>
      visitor.visitStringExpression(this);

  /// Interpolation that, when evaluated, produces the syntax of this string.
  ///
  /// Unlike [text], his doesn't resolve escapes and does include quotes for
  /// quoted strings.
  ///
  /// If [static] is true, this escapes any `#{` sequences in the string. If
  /// [quote] is passed, it uses that character as the quote mark; otherwise, it
  /// determines the best quote to add by looking at the string.
  Interpolation asInterpolation({bool static = false, int? quote}) {
    if (!hasQuotes) return text;

    quote ??= _bestQuote(text.contents.whereType<String>());
    var buffer = InterpolationBuffer();
    buffer.writeCharCode(quote);
    for (var value in text.contents) {
      assert(value is Expression || value is String);
      switch (value) {
        case Expression():
          buffer.add(value);
        case String():
          _quoteInnerText(value, quote, buffer, static: static);
      }
    }
    buffer.writeCharCode(quote);

    return buffer.interpolation(text.span);
  }

  /// Writes to [buffer] the contents of a string (without quotes) that
  /// evaluates to [text] according to Sass's parsing logic.
  ///
  /// This always adds an escape sequence before [quote]. If [static] is true,
  /// it also escapes any `#{` sequences in the string.
  static void _quoteInnerText(String text, int quote, StringSink buffer,
      {bool static = false}) {
    for (var i = 0; i < text.length; i++) {
      switch (text.codeUnitAt(i)) {
        case int(isNewline: true):
          buffer.writeCharCode($backslash);
          buffer.writeCharCode($a);
          if (i != text.length - 1) {
            if (text.codeUnitAt(i + 1)
                case int(isWhitespace: true) || int(isHex: true)) {
              buffer.writeCharCode($space);
            }
          }

        case $backslash && var codeUnit:
        case var codeUnit when codeUnit == quote:
        case $hash && var codeUnit
            when static &&
                i < text.length - 1 &&
                text.codeUnitAt(i + 1) == $lbrace:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode(codeUnit);

        case var codeUnit:
          buffer.writeCharCode(codeUnit);
      }
    }
  }

  /// Returns the code unit for the best quote to use when converting [strings]
  /// to Sass source.
  static int _bestQuote(Iterable<String> strings) {
    var containsDoubleQuote = false;
    for (var value in strings) {
      for (var codeUnit in value.codeUnits) {
        if (codeUnit == $single_quote) return $double_quote;
        if (codeUnit == $double_quote) containsDoubleQuote = true;
      }
    }
    return containsDoubleQuote ? $single_quote : $double_quote;
  }

  String toString() => asInterpolation().toString();
}
