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

class StringExpression implements Expression {
  /// Interpolation that, when evaluated, produces the semantic content of the
  /// string.
  ///
  /// Unlike [asInterpolation], escapes are resolved and quotes are not
  /// included.
  final Interpolation text;

  FileSpan get span => text.span;

  StringExpression(this.text);

  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor) =>
      visitor.visitStringExpression(this);

  /// Interpolation that, when evaluated, produces the syntax of the string.
  ///
  /// Unlike [text], his doesn't resolve escapes and does include quotes.
  Interpolation asInterpolation({bool static: false, int quote}) {
    quote ??= _bestQuote();
    var buffer = new InterpolationBuffer()..writeCharCode(quote);
    for (var value in text.contents) {
      if (value is Interpolation) {
        buffer.addInterpolation(value);
      } else if (value is String) {
        for (var i = 0; i < value.length; i++) {
          var codeUnit = value.codeUnitAt(i);

          if (isNewline(codeUnit)) {
            buffer.writeCharCode($backslash);
            buffer.writeCharCode($a);
            var next = i == value.length - 1 ? null : value.codeUnitAt(i + 1);
            if (isWhitespace(next) || isHex(next)) buffer.writeCharCode($space);
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
    buffer.writeCharCode(quote);

    return buffer.interpolation(text.span);
  }

  int _bestQuote() {
    var containsDoubleQuote = false;
    for (var value in text.contents) {
      for (var i = 0; i < value.length; i++) {
        var codeUnit = value.codeUnitAt(i);
        if (codeUnit == $single_quote) return $double_quote;
        if (codeUnit == $double_quote) containsDoubleQuote = true;
      }
    }
    return containsDoubleQuote ? $single_quote : $double_quote;
  }
}
