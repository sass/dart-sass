// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../callable.dart';
import '../exception.dart';
import '../module/built_in.dart';
import '../value.dart';

/// The global definitions of Sass list functions.
final global = UnmodifiableListView([
  _length.withDeprecationWarning('list'),
  _nth.withDeprecationWarning('list'),
  _setNth.withDeprecationWarning('list'),
  _join.withDeprecationWarning('list'),
  _append.withDeprecationWarning('list'),
  _zip.withDeprecationWarning('list'),
  _index.withDeprecationWarning('list'),
  _isBracketed.withDeprecationWarning('list'),
  _separator.withDeprecationWarning('list').withName("list-separator")
]);

/// The Sass list module.
final module = BuiltInModule("list", functions: <Callable>[
  _length, _nth, _setNth, _join, _append, _zip, _index, _isBracketed, //
  _separator, _slash
]);

final _length = _function(
    "length", r"$list", (arguments) => SassNumber(arguments[0].asList.length));

final _nth = _function("nth", r"$list, $n", (arguments) {
  var list = arguments[0];
  var index = arguments[1];
  return list.asList[list.sassIndexToListIndex(index, "n")];
});

final _setNth = _function("set-nth", r"$list, $n, $value", (arguments) {
  var list = arguments[0];
  var index = arguments[1];
  var value = arguments[2];
  var newList = list.asList.toList();
  newList[list.sassIndexToListIndex(index, "n")] = value;
  return list.withListContents(newList);
});

final _join = _function(
    "join", r"$list1, $list2, $separator: auto, $bracketed: auto", (arguments) {
  var list1 = arguments[0];
  var list2 = arguments[1];
  var separatorParam = arguments[2].assertString("separator");
  var bracketedParam = arguments[3];

  var separator = switch (separatorParam.text) {
    "auto" => switch ((list1.separator, list2.separator)) {
        (ListSeparator.undecided, ListSeparator.undecided) =>
          ListSeparator.space,
        (ListSeparator.undecided, var separator) ||
        (var separator, _) =>
          separator
      },
    "space" => ListSeparator.space,
    "comma" => ListSeparator.comma,
    "slash" => ListSeparator.slash,
    _ => throw SassScriptException(
        '\$separator: Must be "space", "comma", "slash", or "auto".')
  };

  var bracketed = bracketedParam is SassString && bracketedParam.text == 'auto'
      ? list1.hasBrackets
      : bracketedParam.isTruthy;

  var newList = [...list1.asList, ...list2.asList];
  return SassList(newList, separator, brackets: bracketed);
});

final _append =
    _function("append", r"$list, $val, $separator: auto", (arguments) {
  var list = arguments[0];
  var value = arguments[1];
  var separatorParam = arguments[2].assertString("separator");

  var separator = switch (separatorParam.text) {
    "auto" => list.separator == ListSeparator.undecided
        ? ListSeparator.space
        : list.separator,
    "space" => ListSeparator.space,
    "comma" => ListSeparator.comma,
    "slash" => ListSeparator.slash,
    _ => throw SassScriptException(
        '\$separator: Must be "space", "comma", "slash", or "auto".')
  };

  var newList = [...list.asList, value];
  return list.withListContents(newList, separator: separator);
});

final _zip = _function("zip", r"$lists...", (arguments) {
  var lists = arguments[0].asList.map((list) => list.asList).toList();
  if (lists.isEmpty) {
    return const SassList.empty(separator: ListSeparator.comma);
  }

  var i = 0;
  var results = <SassList>[];
  while (lists.every((list) => i != list.length)) {
    results.add(SassList(lists.map((list) => list[i]), ListSeparator.space));
    i++;
  }
  return SassList(results, ListSeparator.comma);
});

final _index = _function("index", r"$list, $value", (arguments) {
  var list = arguments[0].asList;
  var value = arguments[1];

  var index = list.indexOf(value);
  return index == -1 ? sassNull : SassNumber(index + 1);
});

final _separator = _function(
    "separator",
    r"$list",
    (arguments) => switch (arguments[0].separator) {
          ListSeparator.comma => SassString("comma", quotes: false),
          ListSeparator.slash => SassString("slash", quotes: false),
          _ => SassString("space", quotes: false)
        });

final _isBracketed = _function("is-bracketed", r"$list",
    (arguments) => SassBoolean(arguments[0].hasBrackets));

final _slash = _function("slash", r"$elements...", (arguments) {
  var list = arguments[0].asList;
  if (list.length < 2) {
    throw SassScriptException("At least two elements are required.");
  }

  return SassList(list, ListSeparator.slash);
});

/// Like [BuiltInCallable.function], but always sets the URL to `sass:list`.
BuiltInCallable _function(
        String name, String arguments, Value callback(List<Value> arguments)) =>
    BuiltInCallable.function(name, arguments, callback, url: "sass:list");
