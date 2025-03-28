// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';

import '../exception.dart';
import '../util/character.dart';
import '../utils.dart';
import '../value.dart';
import '../visitor/interface/value.dart';

/// A quoted empty string, returned by [SassString.empty].
final _emptyQuoted = SassString("", quotes: true);

/// An unquoted empty string, returned by [SassString.empty].
final _emptyUnquoted = SassString("", quotes: false);

/// A SassScript string.
///
/// Strings can either be quoted or unquoted. Unquoted strings are usually CSS
/// identifiers, but they may contain any text.
///
/// {@category Value}
@sealed
class SassString extends Value {
  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

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
  String get text => _text;
  final String _text;

  /// Whether this string has quotes.
  bool get hasQuotes => _hasQuotes;
  final bool _hasQuotes;

  /// Sass's notion of the length of this string.
  ///
  /// Sass treats strings as a series of Unicode code points while Dart treats
  /// them as a series of UTF-16 code units. For example, the character U+1F60A,
  /// Smiling Face With Smiling Eyes, is a single Unicode code point but is
  /// represented in UTF-16 as two code units (`0xD83D` and `0xDE0A`). So in
  /// Dart, `"a😊b".length` returns `4`, whereas in Sass `str-length("a😊b")`
  /// returns `3`.
  ///
  /// This returns the same value as `text.runes.length`, but it's more
  /// efficient.
  int get sassLength => _sassLength;
  late final int _sassLength = text.runes.length;

  /// The cached hash code for this number, if it's been computed.
  int? _hashCache;

  /// @nodoc
  @internal
  bool get isSpecialNumber {
    if (hasQuotes) return false;
    if (text.length < "min(_)".length) return false;

    return switch (text.codeUnitAt(0)) {
      $a || $A => equalsLetterIgnoreCase($t, text.codeUnitAt(1)) &&
          equalsLetterIgnoreCase($t, text.codeUnitAt(2)) &&
          equalsLetterIgnoreCase($r, text.codeUnitAt(3)) &&
          text.codeUnitAt(4) == $lparen,
      $c || $C => switch (text.codeUnitAt(1)) {
          $l || $L => equalsLetterIgnoreCase($a, text.codeUnitAt(2)) &&
              equalsLetterIgnoreCase($m, text.codeUnitAt(3)) &&
              equalsLetterIgnoreCase($p, text.codeUnitAt(4)) &&
              text.codeUnitAt(5) == $lparen,
          $a || $A => equalsLetterIgnoreCase($l, text.codeUnitAt(2)) &&
              equalsLetterIgnoreCase($c, text.codeUnitAt(3)) &&
              text.codeUnitAt(4) == $lparen,
          _ => false,
        },
      $v || $V => equalsLetterIgnoreCase($a, text.codeUnitAt(1)) &&
          equalsLetterIgnoreCase($r, text.codeUnitAt(2)) &&
          text.codeUnitAt(3) == $lparen,
      $e || $E => equalsLetterIgnoreCase($n, text.codeUnitAt(1)) &&
          equalsLetterIgnoreCase($v, text.codeUnitAt(2)) &&
          text.codeUnitAt(3) == $lparen,
      $m || $M => switch (text.codeUnitAt(1)) {
          $a || $A => equalsLetterIgnoreCase($x, text.codeUnitAt(2)) &&
              text.codeUnitAt(3) == $lparen,
          $i || $I => equalsLetterIgnoreCase($n, text.codeUnitAt(2)) &&
              text.codeUnitAt(3) == $lparen,
          _ => false,
        },
      _ => false,
    };
  }

  /// @nodoc
  @internal
  bool get isVar {
    if (hasQuotes) return false;
    if (text.length < "var(--_)".length) return false;

    return equalsLetterIgnoreCase($v, text.codeUnitAt(0)) &&
        equalsLetterIgnoreCase($a, text.codeUnitAt(1)) &&
        equalsLetterIgnoreCase($r, text.codeUnitAt(2)) &&
        text.codeUnitAt(3) == $lparen;
  }

  /// @nodoc
  @internal
  bool get isBlank => !hasQuotes && text.isEmpty;

  /// Creates an empty string.
  factory SassString.empty({bool quotes = true}) =>
      quotes ? _emptyQuoted : _emptyUnquoted;

  /// Creates a string with the given [text].
  SassString(this._text, {bool quotes = true}) : _hasQuotes = quotes;

  /// Throws a [SassScriptException] if this is an unquoted string.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  ///
  /// @nodoc
  @internal
  void assertQuoted([String? name]) {
    if (hasQuotes) return;
    throw SassScriptException('Expected $this to be a quoted string.', name);
  }

  /// Throws a [SassScriptException] if this is a quoted string.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  ///
  /// @nodoc
  @internal
  void assertUnquoted([String? name]) {
    if (!hasQuotes) return;
    throw SassScriptException('Expected $this to be an unquoted string.', name);
  }

  /// Converts [sassIndex] into a Dart-style index into [text].
  ///
  /// Sass indexes are one-based, while Dart indexes are zero-based. Sass
  /// indexes may also be negative in order to index from the end of the string.
  ///
  /// In addition, Sass indices refer to Unicode code points while Dart string
  /// indices refer to UTF-16 code units. For example, the character U+1F60A,
  /// Smiling Face With Smiling Eyes, is a single Unicode code point but is
  /// represented in UTF-16 as two code units (`0xD83D` and `0xDE0A`). So in
  /// Dart, `"a😊b".codeUnitAt(1)` returns `0xD83D`, whereas in Sass
  /// `str-slice("a😊b", 1, 1)` returns `"😊"`.
  ///
  /// This function converts Sass's code point indexes to Dart's code unit
  /// indexes. This means it's O(n) in the length of [text]. See also
  /// [sassIndexToRuneIndex], which is O(1) and returns an index into the
  /// string's code points (accessible via `text.runes`).
  ///
  /// Throws a [SassScriptException] if [sassIndex] isn't a number, if that
  /// number isn't an integer, or if that integer isn't a valid index for this
  /// string. If [sassIndex] came from a function argument, [name] is the
  /// argument name (without the `$`). It's used for error reporting.
  int sassIndexToStringIndex(Value sassIndex, [String? name]) =>
      codepointIndexToCodeUnitIndex(
        text,
        sassIndexToRuneIndex(sassIndex, name),
      );

  /// Converts [sassIndex] into a Dart-style index into [text]`.runes`.
  ///
  /// Sass indexes are one-based, while Dart indexes are zero-based. Sass
  /// indexes may also be negative in order to index from the end of the string.
  ///
  /// See also [sassIndexToStringIndex], which an index into [text] directly.
  ///
  /// Throws a [SassScriptException] if [sassIndex] isn't a number, if that
  /// number isn't an integer, or if that integer isn't a valid index for this
  /// string. If [sassIndex] came from a function argument, [name] is the
  /// argument name (without the `$`). It's used for error reporting.
  int sassIndexToRuneIndex(Value sassIndex, [String? name]) {
    var index = sassIndex.assertNumber(name).assertInt(name);
    if (index == 0) {
      throw SassScriptException("String index may not be 0.", name);
    } else if (index.abs() > sassLength) {
      throw SassScriptException(
        "Invalid index $sassIndex for a string with $sassLength characters.",
        name,
      );
    }

    return index < 0 ? sassLength + index : index - 1;
  }

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitString(this);

  SassString assertString([String? name]) => this;

  /// @nodoc
  @internal
  Value plus(Value other) => other is SassString
      ? SassString(text + other.text, quotes: hasQuotes)
      : SassString(text + other.toCssString(), quotes: hasQuotes);

  bool operator ==(Object other) => other is SassString && text == other.text;

  int get hashCode => _hashCache ??= text.hashCode;
}
