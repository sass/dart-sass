// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import '../util/map.dart';

@JS('immutable.isList')
external bool _isImmutableList(JSAny? object);

@JS('immutable.List')
extension type ImmutableList<E extends JSAny?>._(JSObject _)
    implements JSObject {
  /// Returns whether [value] is an [ImmutableList].
  static bool isA(JSAny? value) => _isImmutableList(value);

  /// Copies this to a Dart list containing the same elements.
  List<E> get toDart => toArray().toDart;

  external ImmutableList([JSArray<E>? contents]);

  external JSArray<E> toArray();
}

@JS('immutable.isOrderedMap')
external bool _isImmutableMap(JSAny? object);

@JS('immutable.OrderedMap')
extension type ImmutableMap<K extends JSAny?, V extends JSAny?>._(JSObject _)
    implements JSObject {
  /// Returns whether [value] is an [ImmutableMap].
  static bool isA(JSAny? value) => _isImmutableMap(value);

  /// Copies this to a Dart [Map] containing the same key/value pairs.
  ///
  /// Note that in general a Dart map may not have exactly the same notion of
  /// equality as the immutable package (although in practice in Sass we ensure
  /// that it does).
  Map<K, V> get toDart {
    var dartMap = <K, V>{};
    forEach((value, key) {
      dartMap[key] = value;
    });
    return dartMap;
  }

  external ImmutableMap([JSArray<JSArray<JSAny?>>? entries]);

  external ImmutableMap<K, V> asMutable();
  external ImmutableMap<K, V> asImmutable();
  external ImmutableMap<K, V> set(K key, V? value);

  @JS('forEach')
  external void _forEach(JSFunction callback);
  void forEach(void Function(V, K) callback) => _forEach(callback.toJS);
}

extension JSObjectToDartList on JSObject {
  /// Converts this from either a [JSArray] or an [ImmutableList] to a Dart
  /// [List].
  ///
  /// This may not create a copy of the underlying list, so the returned list
  /// should not be modified. It assumes that this object is one of the two
  /// possible list types; if it's not, behavior is undefiend.
  List<E> toDartList<E extends JSAny?>() => ImmutableList.isA(this)
      ? (this as ImmutableList<E>).toDart
      : (this as JSArray<E>).toDart;
}

/// Converts a list of [num]s directly to a [JSArray] of [JSNumber]s.
extension ListOfNumberToImmutableList on List<num> {
  /// Converts this to an [ImmutableList] of [JSNumber]s.
  ImmutableList<JSNumber> get toJSImmutable =>
      ImmutableList(!(this as JSAny).isA<JSArray>()
          ? [for (var value in this) value.toJS].toJS
          : this as JSArray<JSNumber>);
}

/// Converts a list of [String]s directly to an [ImmutableList] of [JSString]s.
extension ListOfStringToImmutableList on List<String> {
  /// Converts this to an [ImmutableList] of [JSString]s.
  ImmutableList<JSString> get toJSImmutable =>
      ImmutableList(!(this as JSAny).isA<JSArray>()
          ? [for (var value in this) value.toJS].toJS
          : this as JSArray<JSString>);
}

/// Converts a list of [JSBoolean]s directly to an [ImmutableList] of [JSBoolean]s.
extension ListOfBooleanToImmutableList on List<bool> {
  /// Converts this to an [ImmutableList] of [JSBoolean]s.
  ImmutableList<JSBoolean> get toJSImmutable =>
      ImmutableList(!(this as JSAny).isA<JSArray>()
          ? [for (var value in this) value.toJS].toJS
          : this as JSArray<JSBoolean>);
}

/// Converts a list in nullable [num]s directly to an [ImmutableList] of [JSNumber]s.
extension ListOfNullableNumberToImmutableList on List<num?> {
  /// Converts this to an [ImmutableList] of [JSNumber]s.
  ImmutableList<JSNumber?> get toJSImmutable =>
      ImmutableList(!(this as JSAny).isA<JSArray>()
          ? [for (var value in this) value?.toJS].toJS
          : this as JSArray<JSNumber?>);
}

/// Converts a list in nullable [String]s directly to an [ImmutableList] of
/// [JSString]s.
extension ListOfNullableStringToImmutableList on List<String?> {
  /// Converts this to an [ImmutableList] of [String]s.
  ImmutableList<JSString?> get toJSImmutable =>
      ImmutableList(!(this as JSAny).isA<JSArray>()
          ? [for (var value in this) value?.toJS].toJS
          : this as JSArray<JSString?>);
}

/// Converts a list in nullale [bool]s directly to an [ImmutableList] of [JSBoolean]s.
extension ListOfNullableBooleanToImmutableList on List<bool?> {
  /// Converts this to an [ImmutableList] of [JSBoolean]s.
  ImmutableList<JSBoolean?> get toJSImmutable =>
      ImmutableList(!(this as JSAny).isA<JSArray>()
          ? [for (var value in this) value?.toJS].toJS
          : this as JSArray<JSBoolean?>);
}

extension ListToImmutableList<E extends JSAny?> on List<E> {
  // TODO - dart-lang/sdk#61327: Just call toJS here
  /// Copies this to an [ImmutableList] containing the same values.
  ImmutableList<E> get toJSImmutable =>
      ImmutableList<E>(!(this as JSAny).isA<JSArray>() ? [...this].toJS : toJS);
}

extension JSArrayToImmutableList<E extends JSAny?> on JSArray<E> {
  /// Copies this to an [ImmutableList] containing the same values.
  ImmutableList<E> get toJSImmutable => ImmutableList<E>(this);
}

extension MapToImmutableMap<K extends JSAny?, V extends JSAny?> on Map<K, V> {
  /// Copies this to an [ImmutableMap] containing the same key/value pairs.
  ///
  /// Note that in general an [ImmutableMap] may not have exactly the same
  /// notion of equality as Dart (although in practice in Sass we ensure that it
  /// does).
  ImmutableMap<K, V> get toJSImmutable {
    var immutableMap = ImmutableMap<K, V>().asMutable();
    for (var (key, value) in pairs) {
      immutableMap = immutableMap.set(key, value);
    }
    return immutableMap.asImmutable();
  }
}
