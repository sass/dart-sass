// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'callable/async.dart';
import 'callable/built_in.dart';
import 'value.dart';
import 'value/external/value.dart' as ext;

export 'callable/async.dart';
export 'callable/async_built_in.dart';
export 'callable/built_in.dart';
export 'callable/plain_css.dart';
export 'callable/user_defined.dart';

/// An interface functions and mixins that can be invoked from Sass by passing
/// in arguments.
///
/// This extends [AsyncCallable] because all synchronous callables are also
/// usable in asynchronous contexts. [Callable]s are usable with both the
/// synchronous and asynchronous `compile()` functions, and as such should be
/// used in preference to [AsyncCallable]s if possible.
///
/// When writing custom functions, it's important to make them as user-friendly
/// and as close to the standards set by Sass's core functions as possible. Some
/// good guidelines to follow include:
///
/// * Use `Value.assert*` methods, like [Value.assertString], to cast untyped
///   `Value` objects to more specific types. For values from the argument list,
///   pass in the argument name as well. This ensures that the user gets good
///   error messages when they pass in the wrong type to your function.
///
/// * Individual classes may have more specific `assert*` methods, like
///   [SassNumber.assertInt], which should be used when possible.
///
/// * In Sass, every value counts as a list. Functions should avoid casting
///   values to the `SassList` type, and should use the [Value.asList] method
///   instead.
///
/// * When manipulating values like lists, strings, and numbers that have
///   metadata (comma versus sepace separated, bracketed versus unbracketed,
///   quoted versus unquoted, units), the output metadata should match the input
///   metadata. For lists, the [Value.changeList] method can be used to do this
///   automatically.
///
/// * When in doubt, lists should default to comma-separated, strings should
///   default to quoted, and number should default to unitless.
///
/// * In Sass, lists and strings use one-based indexing and use negative indices
///   to index from the end of value. Functions should follow these conventions.
///   The [Value.sassIndexToListIndex] and [SassString.sassIndexToStringIndex]
///   methods can be used to do this automatically.
///
/// * String indexes in Sass refer to Unicode code points while Dart string
///   indices refer to UTF-16 code units. For example, the character U+1F60A,
///   Smiling Face With Smiling Eyes, is a single Unicode code point but is
///   represented in UTF-16 as two code units (`0xD83D` and `0xDE0A`). So in
///   Dart, `"a😊b".codeUnitAt(1)` returns `0xD83D`, whereas in Sass
///   `str-slice("a😊b", 1, 1)` returns `"😊"`. Functions should follow this
///   convention. The [SassString.sassIndexToStringIndex] and
///   [SassString.sassIndexToRuneIndex] methods can be used to do this
///   automatically, and the [SassString.sassLength] getter can be used to
///   access a string's length in code points.
abstract class Callable extends AsyncCallable {
  /// Creates a callable with the given [name] and [arguments] that runs
  /// [callback] when called.
  ///
  /// The argument declaration is parsed from [arguments], which uses the same
  /// syntax as an argument list written in Sass (not including parentheses).
  /// The [arguments] list may be empty to indicate that the function takes no
  /// arguments. Arguments may also have default values. Throws a
  /// [SassFormatException] if parsing fails.
  ///
  /// Any exceptions thrown by [callback] are automatically converted to Sass
  /// errors and associated with the function call.
  ///
  /// For example:
  ///
  /// ```dart
  /// new Callable("str-split", r'$string, $divider: " "', (arguments) {
  ///   var string = arguments[0].assertString("string");
  ///   var divider = arguments[1].assertString("divider");
  ///   return new SassList(
  ///       string.value.split(divider.value).map((substring) =>
  ///           new SassString(substring, quotes: string.hasQuotes)),
  ///       ListSeparator.comma);
  /// });
  /// ```
  ///
  /// Callables may also take variable length argument lists. These are declared
  /// the same way as in Sass, and are passed as the final argument to the
  /// callback. For example:
  ///
  /// ```dart
  /// new Callable("str-join", r'$strings...', (arguments) {
  ///   var args = arguments.first as SassArgumentList;
  ///   var strings = args.map((arg) => arg.assertString()).toList();
  ///   return new SassString(strings.map((string) => string.text).join(),
  ///       quotes: strings.any((string) => string.hasQuotes));
  /// });
  /// ```
  ///
  /// Note that the argument list is always an instance of [SassArgumentList],
  /// which provides access to keyword arguments using
  /// [SassArgumentList.keywords].
  factory Callable(String name, String arguments,
          ext.Value callback(List<ext.Value> arguments)) =>
      new BuiltInCallable(
          name, arguments, (arguments) => callback(arguments) as Value);
}
