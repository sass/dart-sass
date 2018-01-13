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

  /// Creates an empty string.
  ///
  /// The [quotes] argument defaults to `false`.
  factory SassString.empty({bool quotes}) = internal.SassString.empty;

  /// Creates a string with the given [text].
  ///
  /// The [quotes] argument defaults to `false`.
  factory SassString(String text, {bool quotes}) = internal.SassString;
}
