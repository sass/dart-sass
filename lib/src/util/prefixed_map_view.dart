// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

/// An unmodifiable view of a map with string keys that allows keys to be
/// accessed with an additional prefix.
class PrefixedMapView<V>(
  /// The wrapped map.
  final Map<String, V> _map,

  /// The prefix to add to the map keys.
  final String _prefix,
) extends UnmodifiableMapBase<String, V> {
  @override
  Iterable<String> get keys => _PrefixedKeys(this);

  @override
  int get length => _map.length;

  @override
  bool get isEmpty => _map.isEmpty;

  @override
  bool get isNotEmpty => _map.isNotEmpty;

  @override
  V? operator [](Object? key) => key is String && key.startsWith(_prefix)
      ? _map[key.substring(_prefix.length)]
      : null;

  @override
  bool containsKey(Object? key) => key is String && key.startsWith(_prefix)
      ? _map.containsKey(key.substring(_prefix.length))
      : false;
}

/// The implementation of [PrefixedMapViews.keys].
class _PrefixedKeys(
  /// The view whose keys are being iterated over.
  final PrefixedMapView<Object?> _view,
) extends IterableBase<String> {
  @override
  int get length => _view.length;
  @override
  Iterator<String> get iterator =>
      _view._map.keys.map((key) => "${_view._prefix}$key").iterator;

  @override
  bool contains(Object? key) => _view.containsKey(key);
}
