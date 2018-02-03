// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../exception.dart';
import '../util/character.dart';
import '../utils.dart';
import '../value.dart';
import '../visitor/interface/value.dart';
import 'external/value.dart' as ext;

/// A quoted empty string, returned by [SassString.empty].
final _emptyQuoted = new SassString("", quotes: true);

/// An unquoted empty string, returned by [SassString.empty].
final _emptyUnquoted = new SassString("", quotes: false);

class SassString extends Value implements ext.SassString {
  final String text;

  final bool hasQuotes;

  int get sassLength {
    _sassLength ??= text.runes.length;
    return _sassLength;
  }

  int _sassLength;

  bool get isSpecialNumber {
    if (hasQuotes) return false;
    if (text.length < "calc(_)".length) return false;

    var first = text.codeUnitAt(0);
    if (equalsLetterIgnoreCase($c, first)) {
      if (!equalsLetterIgnoreCase($a, text.codeUnitAt(1))) return false;
      if (!equalsLetterIgnoreCase($l, text.codeUnitAt(2))) return false;
      if (!equalsLetterIgnoreCase($c, text.codeUnitAt(3))) return false;
      return text.codeUnitAt(4) == $lparen;
    } else if (equalsLetterIgnoreCase($v, first)) {
      if (!equalsLetterIgnoreCase($a, text.codeUnitAt(1))) return false;
      if (!equalsLetterIgnoreCase($r, text.codeUnitAt(2))) return false;
      return text.codeUnitAt(3) == $lparen;
    } else {
      return false;
    }
  }

  bool get isVar {
    if (hasQuotes) return false;
    if (text.length < "var(--_)".length) return false;

    return equalsLetterIgnoreCase($v, text.codeUnitAt(0)) &&
        equalsLetterIgnoreCase($a, text.codeUnitAt(1)) &&
        equalsLetterIgnoreCase($r, text.codeUnitAt(2)) &&
        text.codeUnitAt(3) == $lparen;
  }

  bool get isBlank => !hasQuotes && text.isEmpty;

  factory SassString.empty({bool quotes: true}) =>
      quotes ? _emptyQuoted : _emptyUnquoted;

  SassString(this.text, {bool quotes: true}) : hasQuotes = quotes;

  int sassIndexToStringIndex(ext.Value sassIndex, [String name]) =>
      codepointIndexToCodeUnitIndex(
          text, sassIndexToRuneIndex(sassIndex, name));

  int sassIndexToRuneIndex(ext.Value sassIndex, [String name]) {
    var index = sassIndex.assertNumber(name).assertInt(name);
    if (index == 0) throw _exception("String index may not be 0.", name);
    if (index.abs() > sassLength) {
      throw _exception(
          "Invalid index $sassIndex for a string with $sassLength characters.",
          name);
    }

    return index < 0 ? sassLength + index : index - 1;
  }

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitString(this);

  SassString assertString([String name]) => this;

  Value plus(Value other) {
    if (other is SassString) {
      return new SassString(text + other.text, quotes: hasQuotes);
    } else {
      return new SassString(text + other.toCssString(), quotes: hasQuotes);
    }
  }

  bool operator ==(other) => other is SassString && text == other.text;

  int get hashCode => text.hashCode;

  /// Throws a [SassScriptException] with the given [message].
  SassScriptException _exception(String message, [String name]) =>
      new SassScriptException(name == null ? message : "\$$name: $message");
}
