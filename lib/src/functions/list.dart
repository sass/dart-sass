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
  _length, _nth, _setNth, _join, _append, _zip, _index, _isBracketed, //
  _separator.withName("list-separator")
]);

/// The Sass list module.
final module = BuiltInModule("list", functions: [
  _length, _nth, _setNth, _join, _append, _zip, _index, _isBracketed, //
  _separator
]);

final _length = BuiltInCallable(
    "length", r"$list", (arguments) => SassNumber(arguments[0].asList.length));

final _nth = BuiltInCallable("nth", r"$list, $n", (arguments) {
  var list = arguments[0];
  var index = arguments[1];
  return list.asList[list.sassIndexToListIndex(index, "n")];
});

final _setNth = BuiltInCallable("set-nth", r"$list, $n, $value", (arguments) {
  var list = arguments[0];
  var index = arguments[1];
  var value = arguments[2];
  var newList = list.asList.toList();
  newList[list.sassIndexToListIndex(index, "n")] = value;
  return arguments[0].changeListContents(newList);
});

final _join = BuiltInCallable(
    "join", r"$list1, $list2, $separator: auto, $bracketed: auto", (arguments) {
  var list1 = arguments[0];
  var list2 = arguments[1];
  var separatorParam = arguments[2].assertString("separator");
  var bracketedParam = arguments[3];

  ListSeparator separator;
  if (separatorParam.text == "auto") {
    if (list1.separator != ListSeparator.undecided) {
      separator = list1.separator;
    } else if (list2.separator != ListSeparator.undecided) {
      separator = list2.separator;
    } else {
      separator = ListSeparator.space;
    }
  } else if (separatorParam.text == "space") {
    separator = ListSeparator.space;
  } else if (separatorParam.text == "comma") {
    separator = ListSeparator.comma;
  } else {
    throw SassScriptException(
        '\$separator: Must be "space", "comma", or "auto".');
  }

  var bracketed = bracketedParam is SassString && bracketedParam.text == 'auto'
      ? list1.hasBrackets
      : bracketedParam.isTruthy;

  var newList = [...list1.asList, ...list2.asList];
  return SassList(newList, separator, brackets: bracketed);
});

final _append =
    BuiltInCallable("append", r"$list, $val, $separator: auto", (arguments) {
  var list = arguments[0];
  var value = arguments[1];
  var separatorParam = arguments[2].assertString("separator");

  ListSeparator separator;
  if (separatorParam.text == "auto") {
    separator = list.separator == ListSeparator.undecided
        ? ListSeparator.space
        : list.separator;
  } else if (separatorParam.text == "space") {
    separator = ListSeparator.space;
  } else if (separatorParam.text == "comma") {
    separator = ListSeparator.comma;
  } else {
    throw SassScriptException(
        '\$separator: Must be "space", "comma", or "auto".');
  }

  var newList = [...list.asList, value];
  return list.changeListContents(newList, separator: separator);
});

final _zip = BuiltInCallable("zip", r"$lists...", (arguments) {
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

final _index = BuiltInCallable("index", r"$list, $value", (arguments) {
  var list = arguments[0].asList;
  var value = arguments[1];

  var index = list.indexOf(value);
  return index == -1 ? sassNull : SassNumber(index + 1);
});

final _separator = BuiltInCallable(
    "separator",
    r"$list",
    (arguments) => arguments[0].separator == ListSeparator.comma
        ? SassString("comma", quotes: false)
        : SassString("space", quotes: false));

final _isBracketed = BuiltInCallable("is-bracketed", r"$list",
    (arguments) => SassBoolean(arguments[0].hasBrackets));
