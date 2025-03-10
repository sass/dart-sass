// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';

import '../callable.dart';
import '../exception.dart';
import '../module/built_in.dart';
import '../util/character.dart';
import '../utils.dart';
import '../value.dart';

/// The random number generator for unique IDs.
final _random = math.Random();

// We use base-36 so we can use the (26-character) alphabet and all digits.
var _previousUniqueId = _random.nextInt(math.pow(36, 6) as int);

/// The global definitions of Sass string functions.
final global = UnmodifiableListView([
  _unquote.withDeprecationWarning('string'),
  _quote.withDeprecationWarning('string'),
  _toUpperCase.withDeprecationWarning('string'),
  _toLowerCase.withDeprecationWarning('string'),
  _uniqueId.withDeprecationWarning('string'),
  _length.withDeprecationWarning('string').withName("str-length"),
  _insert.withDeprecationWarning('string').withName("str-insert"),
  _index.withDeprecationWarning('string').withName("str-index"),
  _slice.withDeprecationWarning('string').withName("str-slice"),
]);

/// The Sass string module.
final module = BuiltInModule(
  "string",
  functions: <Callable>[
    _unquote, _quote, _toUpperCase, _toLowerCase, _length, _insert, _index, //
    _slice, _uniqueId,

    _function("split", r"$string, $separator, $limit: null", (arguments) {
      var string = arguments[0].assertString("string");
      var separator = arguments[1].assertString("separator");
      var limit =
          arguments[2].realNull?.assertNumber("limit").assertInt("limit");

      if (limit != null && limit < 1) {
        throw SassScriptException("\$limit: Must be 1 or greater, was $limit.");
      }

      if (string.text.isEmpty) {
        return const SassList.empty(
          separator: ListSeparator.comma,
          brackets: true,
        );
      } else if (separator.text.isEmpty) {
        return SassList(
          string.text.runes.map(
            (rune) =>
                SassString(String.fromCharCode(rune), quotes: string.hasQuotes),
          ),
          ListSeparator.comma,
          brackets: true,
        );
      }

      var i = 0;
      var lastEnd = 0;
      var chunks = <String>[];
      for (var match in separator.text.allMatches(string.text)) {
        chunks.add(string.text.substring(lastEnd, match.start));
        lastEnd = match.end;

        i++;
        if (i == limit) break;
      }
      chunks.add(string.text.substring(lastEnd));

      return SassList(
        chunks.map((chunk) => SassString(chunk, quotes: string.hasQuotes)),
        ListSeparator.comma,
        brackets: true,
      );
    }),
  ],
);

final _unquote = _function("unquote", r"$string", (arguments) {
  var string = arguments[0].assertString("string");
  if (!string.hasQuotes) return string;
  return SassString(string.text, quotes: false);
});

final _quote = _function("quote", r"$string", (arguments) {
  var string = arguments[0].assertString("string");
  if (string.hasQuotes) return string;
  return SassString(string.text, quotes: true);
});

final _length = _function("length", r"$string", (arguments) {
  var string = arguments[0].assertString("string");
  return SassNumber(string.sassLength);
});

final _insert = _function("insert", r"$string, $insert, $index", (arguments) {
  var string = arguments[0].assertString("string");
  var insert = arguments[1].assertString("insert");
  var index = arguments[2].assertNumber("index");
  index.assertNoUnits("index");

  var indexInt = index.assertInt("index");

  // str-insert has unusual behavior for negative inputs. It guarantees that
  // the `$insert` string is at `$index` in the result, which means that we
  // want to insert before `$index` if it's positive and after if it's
  // negative.
  if (indexInt < 0) {
    // +1 because negative indexes start counting from -1 rather than 0, and
    // another +1 because we want to insert *after* that index.
    indexInt = math.max(string.sassLength + indexInt + 2, 0);
  }

  var codepointIndex = _codepointForIndex(indexInt, string.sassLength);
  var codeUnitIndex = codepointIndexToCodeUnitIndex(
    string.text,
    codepointIndex,
  );
  return SassString(
    string.text.replaceRange(codeUnitIndex, codeUnitIndex, insert.text),
    quotes: string.hasQuotes,
  );
});

final _index = _function("index", r"$string, $substring", (arguments) {
  var string = arguments[0].assertString("string");
  var substring = arguments[1].assertString("substring");

  var codeUnitIndex = string.text.indexOf(substring.text);
  if (codeUnitIndex == -1) return sassNull;
  var codepointIndex = codeUnitIndexToCodepointIndex(
    string.text,
    codeUnitIndex,
  );
  return SassNumber(codepointIndex + 1);
});

final _slice = _function("slice", r"$string, $start-at, $end-at: -1", (
  arguments,
) {
  var string = arguments[0].assertString("string");
  var start = arguments[1].assertNumber("start-at");
  var end = arguments[2].assertNumber("end-at");
  start.assertNoUnits("start-at");
  end.assertNoUnits("end-at");

  var lengthInCodepoints = string.sassLength;

  // No matter what the start index is, an end index of 0 will produce an
  // empty string.
  var endInt = end.assertInt();
  if (endInt == 0) return SassString.empty(quotes: string.hasQuotes);

  var startCodepoint = _codepointForIndex(
    start.assertInt(),
    lengthInCodepoints,
  );
  var endCodepoint = _codepointForIndex(
    endInt,
    lengthInCodepoints,
    allowNegative: true,
  );
  if (endCodepoint == lengthInCodepoints) endCodepoint -= 1;
  if (endCodepoint < startCodepoint) {
    return SassString.empty(quotes: string.hasQuotes);
  }

  return SassString(
    string.text.substring(
      codepointIndexToCodeUnitIndex(string.text, startCodepoint),
      codepointIndexToCodeUnitIndex(string.text, endCodepoint + 1),
    ),
    quotes: string.hasQuotes,
  );
});

final _toUpperCase = _function("to-upper-case", r"$string", (arguments) {
  var string = arguments[0].assertString("string");
  var buffer = StringBuffer();
  for (var i = 0; i < string.text.length; i++) {
    buffer.writeCharCode(toUpperCase(string.text.codeUnitAt(i)));
  }
  return SassString(buffer.toString(), quotes: string.hasQuotes);
});

final _toLowerCase = _function("to-lower-case", r"$string", (arguments) {
  var string = arguments[0].assertString("string");
  var buffer = StringBuffer();
  for (var i = 0; i < string.text.length; i++) {
    buffer.writeCharCode(toLowerCase(string.text.codeUnitAt(i)));
  }
  return SassString(buffer.toString(), quotes: string.hasQuotes);
});

final _uniqueId = _function("unique-id", "", (arguments) {
  // Make it difficult to guess the next ID by randomizing the increase.
  _previousUniqueId += _random.nextInt(36) + 1;
  if (_previousUniqueId > math.pow(36, 6)) {
    _previousUniqueId %= math.pow(36, 6) as int;
  }

  // The leading "u" ensures that the result is a valid identifier.
  return SassString(
    "u${_previousUniqueId.toRadixString(36).padLeft(6, '0')}",
    quotes: false,
  );
});

/// Converts a Sass string index into a codepoint index into a string whose
/// [String.runes] has length [lengthInCodepoints].
///
/// A Sass string index is one-based, and uses negative numbers to count
/// backwards from the end of the string. A codepoint index is an index into
/// [String.runes].
///
/// If [index] is negative and it points before the beginning of
/// [lengthInCodepoints], this will return `0` if [allowNegative] is `false` and
/// the index if it's `true`.
int _codepointForIndex(
  int index,
  int lengthInCodepoints, {
  bool allowNegative = false,
}) {
  if (index == 0) return 0;
  if (index > 0) return math.min(index - 1, lengthInCodepoints);
  var result = lengthInCodepoints + index;
  if (result < 0 && !allowNegative) return 0;
  return result;
}

/// Like [BuiltInCallable.function], but always sets the URL to
/// `sass:string`.
BuiltInCallable _function(
  String name,
  String arguments,
  Value callback(List<Value> arguments),
) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:string");
