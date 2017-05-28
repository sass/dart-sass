// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../interpolation_buffer.dart';
import '../../../util/character.dart';
import '../../../visitor/interface/expression.dart';
import '../expression.dart';
import '../interpolation.dart';

/// A string literal.
class StringExpression implements Expression {
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
  static String quoteText(String text) =>
      new StringExpression.plain(text, null, quotes: true)
          .asInterpolation(static: true)
          .asPlain;

  StringExpression(this.text, {bool quotes: false}) : hasQuotes = quotes;

  StringExpression.plain(String text, FileSpan span, {bool quotes: false})
      : text = new Interpolation([text], span),
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
  Interpolation asInterpolation({bool static: false, int quote}) {
    if (!hasQuotes) return text;

    quote ??= hasQuotes ? _bestQuote() : null;
    var buffer = new InterpolationBuffer();
    if (quote != null) buffer.writeCharCode(quote);
    for (var value in text.contents) {
      assert(value is Expression || value is String);
      if (value is Expression) {
        buffer.add(value);
      } else if (value is String) {
        for (var i = 0; i < value.length; i++) {
          var codeUnit = value.codeUnitAt(i);

          if (isNewline(codeUnit)) {
            buffer.writeCharCode($backslash);
            buffer.writeCharCode($a);
            if (i != value.length - 1) {
              var next = value.codeUnitAt(i + 1);
              if (isWhitespace(next) || isHex(next)) {
                buffer.writeCharCode($space);
              }
            }
          } else {
            if (codeUnit == quote ||
                codeUnit == $backslash ||
                (static &&
                    codeUnit == $hash &&
                    i < value.length - 1 &&
                    value.codeUnitAt(i + 1) == $lbrace)) {
              buffer.writeCharCode($backslash);
            }
            buffer.writeCharCode(codeUnit);
          }
        }
      }
    }
    if (quote != null) buffer.writeCharCode(quote);

    return buffer.interpolation(text.span);
  }

  /// Returns the code unit for the best quote to use when converting this
  /// string to Sass source.
  int _bestQuote() {
    var containsDoubleQuote = false;
    for (var value in text.contents) {
      if (value is String) {
        for (var i = 0; i < value.length; i++) {
          var codeUnit = value.codeUnitAt(i);
          if (codeUnit == $single_quote) return $double_quote;
          if (codeUnit == $double_quote) containsDoubleQuote = true;
        }
      }
    }
    return containsDoubleQuote ? $single_quote : $double_quote;
  }

  String toString() => asInterpolation().toString();
}
