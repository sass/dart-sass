// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../utils.dart';

/// An unmodifiable view of a map that only allows certain keys to be accessed.
///
/// Whether or not the underlying map contains keys that aren't allowed, this
/// view will behave as though it doesn't contain them.
///
/// The underlying map's values may change independently of this view, but its
/// set of keys may not.
class LimitedMapView<K, V> extends UnmodifiableMapBase<K, V> {
  /// The wrapped map.
  final Map<K, V> _map;

  /// The allowed keys in [_map].
  final Set<K> _keys;

  Iterable<K> get keys => _keys;
  int get length => _keys.length;
  bool get isEmpty => _keys.isEmpty;
  bool get isNotEmpty => _keys.isNotEmpty;

  /// Returns a [LimitedMapView] that allows only keys in [whitelist].
  ///
  /// The [whitelist] must have the same notion of equality as the [map].
  LimitedMapView.whitelist(this._map, Set<K> whitelist)
      : _keys = whitelist.intersection(MapKeySet(_map));

  /// Returns a [LimitedMapView] that doesn't allow keys in [blacklist].
  ///
  /// The [blacklist] must have the same notion of equality as the [map].
  LimitedMapView.blacklist(this._map, Set<K> blacklist)
      : _keys = toSetWithEquality(
            _map.keys.where((key) => !blacklist.contains(key)), blacklist);

  V operator [](Object key) => _keys.contains(key) ? _map[key] : null;
  bool containsKey(Object key) => _keys.contains(key);
}
