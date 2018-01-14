// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart' as internal;
import 'value.dart';

/// A SassScript string.
///
/// Strings can either be quoted or unquoted. Unquoted strings are usually CSS
/// identifiers, but they may contain any text.
abstract class SassString extends Value {
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
  String get text;

  /// Whether this string has quotes.
  bool get hasQuotes;

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
  int get sassLength;

  /// Creates an empty string.
  ///
  /// The [quotes] argument defaults to `false`.
  factory SassString.empty({bool quotes}) = internal.SassString.empty;

  /// Creates a string with the given [text].
  ///
  /// The [quotes] argument defaults to `false`.
  factory SassString(String text, {bool quotes}) = internal.SassString;

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
  int sassIndexToStringIndex(Value sassIndex, [String name]);

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
  int sassIndexToRuneIndex(Value sassIndex, [String name]);
}
