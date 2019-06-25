// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

/// An unmodifiable view of a map with string keys that allows keys to be
/// accessed with an additional prefix.
class PrefixedMapView<V> extends UnmodifiableMapBase<String, V> {
  /// The wrapped map.
  final Map<String, V> _map;

  /// The prefix to add to the map keys.
  final String _prefix;

  /// The equality operation to use for comparing map keys.
  final bool Function(String string1, String string2) _equals;

  Iterable<String> get keys => _PrefixedKeys(this);
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;

  /// Creates a new prefixed map view.
  ///
  /// The map's notion of equality must match [equals], and must be stable over
  /// substrings (that is, if `T == S`, then for all ranges `i..j`,
  /// `T[i..j] == S[i..j]`).
  PrefixedMapView(this._map, this._prefix,
      {bool equals(String string1, String string2)})
      : _equals = equals ?? ((string1, string2) => string1 == string2);

  V operator [](Object key) => key is String && _startsWith(key, _prefix)
      ? _map[key.substring(_prefix.length)]
      : null;

  bool containsKey(Object key) => key is String && _startsWith(key, _prefix)
      ? _map.containsKey(key.substring(_prefix.length))
      : false;

  /// Returns whether [string] begins with [prefix] according to [_equals].
  bool _startsWith(String string, String prefix) =>
      string.length >= prefix.length &&
      _equals(string.substring(0, prefix.length), prefix);
}

/// The implementation of [PrefixedMapViews.keys].
class _PrefixedKeys extends IterableBase<String> {
  /// The view whose keys are being iterated over.
  final PrefixedMapView<Object> _view;

  int get length => _view.length;
  Iterator<String> get iterator =>
      _view._map.keys.map((key) => "${_view._prefix}$key").iterator;

  _PrefixedKeys(this._view);

  bool contains(Object key) => _view.containsKey(key);
}
