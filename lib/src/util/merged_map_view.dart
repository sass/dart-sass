// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../utils.dart';

/// An unmodifiable view of multiple maps merged together as though they were a
/// single map.
///
/// The values in later maps take precedence over those in earlier maps. When a
/// key is set, it's set in the last map that has an existing value for that
/// key.
///
/// Unlike `CombinedMapView` from the `collection` package, this provides `O(1)`
/// index and `length` operations and provides some degree of mutability. It
/// does so by imposing the additional constraint that the underlying maps' sets
/// of keys remain unchanged.
class MergedMapView<K, V> extends MapBase<K, V> {
  // A map from keys to the maps in which those keys first appear.
  final _mapsByKey = <K, Map<K, V>>{};

  Iterable<K> get keys => _mapsByKey.keys;
  int get length => _mapsByKey.length;
  bool get isEmpty => _mapsByKey.isEmpty;
  bool get isNotEmpty => _mapsByKey.isNotEmpty;

  /// Creates a combined view of [maps].
  ///
  /// Each map must have the default notion of equality. The underlying maps'
  /// values may change independently of this view, but their set of keys may
  /// not.
  MergedMapView(Iterable<Map<K, V>> maps) {
    for (var map in maps) {
      if (map is MergedMapView<K, V>) {
        // Flatten nested merged views to avoid O(depth) overhead.
        for (var child in map._mapsByKey.values) {
          setAll(_mapsByKey, child.keys, child);
        }
      } else {
        setAll(_mapsByKey, map.keys, map);
      }
    }
  }

  V operator [](Object key) {
    var child = _mapsByKey[key];
    return child == null ? null : child[key];
  }

  operator []=(K key, V value) {
    var child = _mapsByKey[key];
    if (child == null) {
      throw UnsupportedError("New entries may not be added to MergedMapView.");
    }

    child[key] = value;
  }

  V remove(Object key) {
    throw UnsupportedError("Entries may not be removed from MergedMapView.");
  }

  void clear() {
    throw UnsupportedError("Entries may not be removed from MergedMapView.");
  }

  bool containsKey(Object key) => _mapsByKey.containsKey(key);
}
