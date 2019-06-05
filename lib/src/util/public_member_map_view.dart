// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../utils.dart';

/// An unmodifiable map view that hides keys from the original map whose names
/// begin with `_` or `-`.
///
/// Note that [PublicMemberMap.length] is *not* `O(1)`.
class PublicMemberMapView<V> extends UnmodifiableMapBase<String, V> {
  /// The wrapped map.
  final Map<String, V> _inner;

  Iterable<String> get keys => _inner.keys.where(isPublic);

  PublicMemberMapView(this._inner);

  bool containsKey(Object key) =>
      key is String && isPublic(key) && _inner.containsKey(key);

  V operator [](Object key) {
    if (key is String && isPublic(key)) return _inner[key];
    return null;
  }
}
