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
class UnprefixedMapView<V>(
  /// The wrapped map.
  final Map<String, V> _map,

  /// The prefix to remove from the map keys.
  final String _prefix,
) extends UnmodifiableMapBase<String, V> {
  @override
  Iterable<String> get keys => _UnprefixedKeys(this);

  @override
  V? operator [](Object? key) => key is String ? _map[_prefix + key] : null;

  @override
  bool containsKey(Object? key) =>
      key is String ? _map.containsKey(_prefix + key) : false;

  @override
  V? remove(Object? key) => key is String ? _map.remove(_prefix + key) : null;
}

/// The implementation of [UnprefixedMapViews.keys].
class _UnprefixedKeys(
  /// The view whose keys are being iterated over.
  final UnprefixedMapView<Object?> _view,
) extends IterableBase<String> {
  @override
  Iterator<String> get iterator => _view._map.keys
      .where((key) => key.startsWith(_view._prefix))
      .map((key) => key.substring(_view._prefix.length))
      .iterator;

  @override
  bool contains(Object? key) => _view.containsKey(key);
}
