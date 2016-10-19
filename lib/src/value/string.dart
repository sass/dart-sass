// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript string.
///
/// Strings can either be quoted or unquoted. Unquoted strings are usually CSS
/// identifiers, but they may contain any text.
class SassString extends Value {
  /// The contents of the string.
  ///
  /// For quoted strings, this is the semantic content—any escape sequences that
  /// were been written in the source text are resolved to their Unicode values.
  /// For unquoted strings, though, escape sequences are preserved as literal
  /// backslashes.
  ///
  /// This difference allows us to distinguish between identifiers with escapes,
  /// such as `url\u28 http://example.com\u29`, and unquoted strings that
  /// contain characters that aren't valid in identifiers, such as
  /// `url(http://example.com)`. Unfortunately, it also means that we don't
  /// consider `foo` and `f\6F\6F` the same string.
  final String text;

  /// Whether this string has quotes.
  final bool hasQuotes;

  bool get isCalc {
    if (hasQuotes) return false;
    if (text.length < 6) return false;
    if (text.codeUnitAt(0) != $c && text.codeUnitAt(0) != $C) return false;
    if (text.codeUnitAt(1) != $a && text.codeUnitAt(1) != $A) return false;
    if (text.codeUnitAt(2) != $l && text.codeUnitAt(2) != $L) return false;
    if (text.codeUnitAt(3) != $c && text.codeUnitAt(3) != $C) return false;
    return text.codeUnitAt(4) == $lparen;
  }

  bool get isBlank => !hasQuotes && text.isEmpty;

  SassString(this.text, {bool quotes: false}) : hasQuotes = quotes;

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitString(this);

  SassString assertString([String name]) => this;

  Value plus(Value other) {
    if (other is SassString) {
      return new SassString(text + other.text,
          quotes: hasQuotes || other.hasQuotes);
    } else {
      return new SassString(text + other.toCssString(), quotes: hasQuotes);
    }
  }

  bool operator ==(other) => other is SassString && text == other.text;

  int get hashCode => text.hashCode;
}
