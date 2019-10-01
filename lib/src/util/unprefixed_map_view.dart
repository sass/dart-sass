// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

/// A mostly-unmodifiable view of a map with string keys that only allows keys
/// with a given prefix to be accessed, and presents them as though they didn't
/// have that prefix.
///
/// Whether or not the underlying map contains keys without the given prefix,
/// this view will behave as though it doesn't contain them.
///
/// This is unmodifiable *except for the [remove] method*, which is used for
/// `@used with` to mark configured variables as used.
class UnprefixedMapView<V> extends UnmodifiableMapBase<String, V> {
  /// The wrapped map.
  final Map<String, V> _map;

  /// The prefix to remove from the map keys.
  final String _prefix;

  Iterable<String> get keys => _UnprefixedKeys(this);

  /// Creates a new unprefixed map view.
  UnprefixedMapView(this._map, this._prefix);

  V operator [](Object key) => key is String ? _map[_prefix + key] : null;

  bool containsKey(Object key) =>
      key is String ? _map.containsKey(_prefix + key) : false;

  V remove(Object key) => key is String ? _map.remove(_prefix + key) : null;
}

/// The implementation of [UnprefixedMapViews.keys].
class _UnprefixedKeys extends IterableBase<String> {
  /// The view whose keys are being iterated over.
  final UnprefixedMapView<Object> _view;

  Iterator<String> get iterator => _view._map.keys
      .where((key) => key.startsWith(_view._prefix))
      .map((key) => key.substring(_view._prefix.length))
      .iterator;

  _UnprefixedKeys(this._view);

  bool contains(Object key) => _view.containsKey(key);
}
