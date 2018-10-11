// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'ast/node.dart';
import 'util/character.dart';

/// The URL used in stack traces when no source URL is available.
final _noSourceUrl = Uri.parse("-");

/// Converts [iter] into a sentence, separating each word with [conjunction].
String toSentence(Iterable iter, [String conjunction]) {
  conjunction ??= "and";
  if (iter.length == 1) return iter.first.toString();
  return iter.take(iter.length - 1).join(", ") + " $conjunction ${iter.last}";
}

/// Returns [string] with every line indented [indentation] spaces.
String indent(String string, int indentation) =>
    string.split("\n").map((line) => (" " * indentation) + line).join("\n");

/// Returns [name] if [number] is 1, or the plural of [name] otherwise.
///
/// By default, this just adds "s" to the end of [name] to get the plural. If
/// [plural] is passed, that's used instead.
String pluralize(String name, int number, {String plural}) {
  if (number == 1) return name;
  if (plural != null) return plural;
  return '${name}s';
}

/// Returns the number of times [codeUnit] appears in [string].
int countOccurrences(String string, int codeUnit) {
  var count = 0;
  for (var i = 0; i < string.length; i++) {
    if (string.codeUnitAt(i) == codeUnit) count++;
  }
  return count;
}

/// Like [String.trim], but only trims ASCII whitespace.
String trimAscii(String string) {
  var start = _firstNonWhitespace(string);
  return start == null
      ? ""
      : string.substring(start, _lastNonWhitespace(string) + 1);
}

/// Like [String.trimLeft], but only trims ASCII whitespace.
String trimAsciiLeft(String string) {
  var start = _firstNonWhitespace(string);
  return start == null ? "" : string.substring(start);
}

/// Like [String.trimRight], but only trims ASCII whitespace.
String trimAsciiRight(String string) {
  var end = _lastNonWhitespace(string);
  return end == null ? "" : string.substring(0, end + 1);
}

/// Returns the index of the first character in [string] that's not ASCII
/// whitepsace, or [null] if [string] is entirely spaces.
int _firstNonWhitespace(String string) {
  for (var i = 0; i < string.length; i++) {
    if (!isWhitespace(string.codeUnitAt(i))) return i;
  }
  return null;
}

/// Returns the index of the last character in [string] that's not ASCII
/// whitespace, or [null] if [string] is entirely spaces.
int _lastNonWhitespace(String string) {
  for (var i = string.length - 1; i >= 0; i--) {
    if (!isWhitespace(string.codeUnitAt(i))) return i;
  }
  return null;
}

/// Flattens the first level of nested arrays in [iterable].
///
/// The return value is ordered first by index in the nested iterable, then by
/// the index *of* that iterable in [iterable]. For example,
/// `flattenVertically([["1a", "1b"], ["2a", "2b"]])` returns `["1a", "2a",
/// "1b", "2b"]`.
List<T> flattenVertically<T>(Iterable<Iterable<T>> iterable) {
  var queues = iterable.map((inner) => new QueueList.from(inner)).toList();
  if (queues.length == 1) return queues.first;

  var result = <T>[];
  while (queues.isNotEmpty) {
    queues.removeWhere((queue) {
      result.add(queue.removeFirst());
      return queue.isEmpty;
    });
  }
  return result;
}

/// Converts [codepointIndex] to a code unit index, relative to [string].
///
/// A codepoint index is the index in pure Unicode codepoints; a code unit index
/// is an index into a UTF-16 string.
int codepointIndexToCodeUnitIndex(String string, int codepointIndex) {
  var codeUnitIndex = 0;
  for (var i = 0; i < codepointIndex; i++) {
    if (isHighSurrogate(string.codeUnitAt(codeUnitIndex++))) codeUnitIndex++;
  }
  return codeUnitIndex;
}

/// Converts [codeUnitIndex] to a codepoint index, relative to [string].
///
/// A codepoint index is the index in pure Unicode codepoints; a code unit index
/// is an index into a UTF-16 string.
int codeUnitIndexToCodepointIndex(String string, int codeUnitIndex) {
  var codepointIndex = 0;
  for (var i = 0; i < codeUnitIndex; i++) {
    codepointIndex++;
    if (isHighSurrogate(string.codeUnitAt(i))) i++;
  }
  return codepointIndex;
}

/// Returns whether [list1] and [list2] have the same contents.
bool listEquals<T>(List<T> list1, List<T> list2) =>
    const ListEquality().equals(list1, list2);

/// Returns a hash code for [list] that matches [listEquals].
int listHash(List list) => const ListEquality().hash(list);

/// Returns a stack frame for the given [span] with the given [member] name.
///
/// By default, the frame's URL is set to `span.sourceUrl`. However, if [url] is
/// passed, it's used instead.
Frame frameForSpan(SourceSpan span, String member, {Uri url}) => new Frame(
    url ?? span.sourceUrl ?? _noSourceUrl,
    span.start.line + 1,
    span.start.column + 1,
    member);

/// Returns a source span that covers the spans of both the first and last nodes
/// in [nodes].
///
/// If [nodes] is empty, or if either the first or last node has a `null` span,
/// returns `null`.
FileSpan spanForList(List<AstNode> nodes) {
  if (nodes.isEmpty) return null;
  // Spans may be null for dynamically-constructed ASTs.
  if (nodes.first.span == null) return null;
  if (nodes.last.span == null) return null;
  return nodes.first.span.expand(nodes.last.span);
}

/// Returns [name] without a vendor prefix.
///
/// If [name] has no vendor prefix, it's returned as-is.
String unvendor(String name) {
  if (name.length < 2) return name;
  if (name.codeUnitAt(0) != $dash) return name;
  if (name.codeUnitAt(1) == $dash) return name;

  for (var i = 2; i < name.length; i++) {
    if (name.codeUnitAt(i) == $dash) return name.substring(i + 1);
  }
  return name;
}

/// Returns whether [string1] and [string2] are equal if `-` and `_` are
/// considered equivalent.
bool equalsIgnoreSeparator(String string1, String string2) {
  if (identical(string1, string2)) return true;
  if (string1 == null || string2 == null) return false;
  if (string1.length != string2.length) return false;
  for (var i = 0; i < string1.length; i++) {
    var codeUnit1 = string1.codeUnitAt(i);
    var codeUnit2 = string2.codeUnitAt(i);
    if (codeUnit1 == codeUnit2) continue;
    if (codeUnit1 == $dash) {
      if (codeUnit2 != $underscore) return false;
    } else if (codeUnit1 == $underscore) {
      if (codeUnit2 != $dash) return false;
    } else {
      return false;
    }
  }
  return true;
}

/// Returns a hash code for [string] that matches [equalsIgnoreSeparator].
int hashCodeIgnoreSeparator(String string) {
  var hash = 4603;
  for (var i = 0; i < string.length; i++) {
    var codeUnit = string.codeUnitAt(i);
    if (codeUnit == $underscore) codeUnit = $dash;
    hash &= 0x3FFFFFF;
    hash *= 33;
    hash ^= codeUnit;
  }
  return hash;
}

/// Returns whether [string1] and [string2] are equal, ignoring ASCII case.
bool equalsIgnoreCase(String string1, String string2) {
  if (identical(string1, string2)) return true;
  if (string1 == null || string2 == null) return false;
  if (string1.length != string2.length) return false;
  return string1.toUpperCase() == string2.toUpperCase();
}

/// Returns an empty map that uses [equalsIgnoreSeparator] for key equality.
///
/// If [source] is passed, copies it into the map.
Map<String, V> normalizedMap<V>([Map<String, V> source]) {
  var map = new LinkedHashMap<String, V>(
      equals: equalsIgnoreSeparator, hashCode: hashCodeIgnoreSeparator);
  if (source != null) map.addAll(source);
  return map;
}

/// Returns an empty set that uses [equalsIgnoreSeparator] for equality.
///
/// If [source] is passed, copies it into the set.
Set<String> normalizedSet([Iterable<String> source]) {
  var set = new LinkedHashSet(
      equals: equalsIgnoreSeparator, hashCode: hashCodeIgnoreSeparator);
  if (source != null) set.addAll(source);
  return set;
}

/// Like [mapMap], but returns a map that uses [equalsIgnoreSeparator] for key
/// equality.
Map<String, V2> normalizedMapMap<K, V1, V2>(Map<K, V1> map,
    {String key(K key, V1 value), V2 value(K key, V1 value)}) {
  key ??= (mapKey, _) => mapKey as String;
  value ??= (_, mapValue) => mapValue as V2;

  var result = normalizedMap<V2>();
  map.forEach((mapKey, mapValue) {
    result[key(mapKey, mapValue)] = value(mapKey, mapValue);
  });
  return result;
}

/// Returns the longest common subsequence between [list1] and [list2].
///
/// If there are more than one equally long common subsequence, returns the one
/// which starts first in [list1].
///
/// If [select] is passed, it's used to check equality between elements in each
/// list. If it returns `null`, the elements are considered unequal; otherwise,
/// it should return the element to include in the return value.
List<T> longestCommonSubsequence<T>(List<T> list1, List<T> list2,
    {T select(T element1, T element2)}) {
  select ??= (element1, element2) => element1 == element2 ? element1 : null;

  var lengths = new List.generate(
      list1.length + 1, (_) => new List.filled(list2.length + 1, 0),
      growable: false);

  var selections = new List<List<T>>.generate(
      list1.length, (_) => new List<T>(list2.length),
      growable: false);

  for (var i = 0; i < list1.length; i++) {
    for (var j = 0; j < list2.length; j++) {
      var selection = select(list1[i], list2[j]);
      selections[i][j] = selection;
      lengths[i + 1][j + 1] = selection == null
          ? math.max(lengths[i + 1][j], lengths[i][j + 1])
          : lengths[i][j] + 1;
    }
  }

  List<T> backtrack(int i, int j) {
    if (i == -1 || j == -1) return [];
    var selection = selections[i][j];
    if (selection != null) return backtrack(i - 1, j - 1)..add(selection);

    return lengths[i + 1][j] > lengths[i][j + 1]
        ? backtrack(i, j - 1)
        : backtrack(i - 1, j);
  }

  return backtrack(list1.length - 1, list2.length - 1);
}

/// Removes and returns the first value in [list] that matches [test].
///
/// By default, throws a [StateError] if no value matches. If [orElse] is
/// passed, its return value is used instead.
T removeFirstWhere<T>(List<T> list, bool test(T value), {T orElse()}) {
  T toRemove;
  for (var element in list) {
    if (!test(element)) continue;
    toRemove = element;
    break;
  }

  if (toRemove == null) {
    if (orElse != null) return orElse();
    throw new StateError("No such element.");
  } else {
    list.remove(toRemove);
    return toRemove;
  }
}

/// Rotates the element in list from [start] (inclusive) to [end] (exclusive)
/// one index higher, looping the final element back to [start].
void rotateSlice(List list, int start, int end) {
  var element = list[end - 1];
  for (var i = start; i < end; i++) {
    var next = list[i];
    list[i] = element;
    element = next;
  }
}

/// Like [Iterable.map] but for an asynchronous [callback].
Future<Iterable<F>> mapAsync<E, F>(
    Iterable<E> iterable, Future<F> callback(E value)) async {
  var result = <F>[];
  for (var element in iterable) {
    result.add(await callback(element));
  }
  return result;
}

/// Like [Map.putIfAbsent], but for an asynchronous [ifAbsent].
///
/// Note that this is *not* safe to call in parallel on the same map with the
/// same key.
Future<V> putIfAbsentAsync<K, V>(
    Map<K, V> map, K key, Future<V> ifAbsent()) async {
  if (map.containsKey(key)) return map[key];
  var value = await ifAbsent();
  map[key] = value;
  return value;
}

/// Like [normalizedMapMap], but for asynchronous [key] and [value].
Future<Map<String, V2>> normalizedMapMapAsync<K, V1, V2>(Map<K, V1> map,
    {Future<String> key(K key, V1 value),
    Future<V2> value(K key, V1 value)}) async {
  key ??= (mapKey, _) async => mapKey as String;
  value ??= (_, mapValue) async => mapValue as V2;

  var result = normalizedMap<V2>();
  for (var mapKey in map.keys) {
    var mapValue = map[mapKey];
    result[await key(mapKey, mapValue)] = await value(mapKey, mapValue);
  }
  return result;
}
