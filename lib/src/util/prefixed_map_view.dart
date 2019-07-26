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

  Iterable<String> get keys => _PrefixedKeys(this);
  int get length => _map.length;
  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;

  /// Creates a new prefixed map view.
  PrefixedMapView(this._map, this._prefix);

  V operator [](Object key) => key is String && key.startsWith(_prefix)
      ? _map[key.substring(_prefix.length)]
      : null;

  bool containsKey(Object key) => key is String && key.startsWith(_prefix)
      ? _map.containsKey(key.substring(_prefix.length))
      : false;
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
