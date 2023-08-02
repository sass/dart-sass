// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

extension MapExtensions<K, V> on Map<K, V> {
  /// If [this] doesn't contain the given [key], sets that key to [value] and
  /// returns it.
  ///
  /// Otherwise, calls [merge] with the existing value and [value] and sets
  /// [key] to the result.
  V putOrMerge(K key, V value, V Function(V oldValue, V newValue) merge) =>
      containsKey(key)
          ? this[key] = merge(this[key] as V, value)
          : this[key] = value;

  // TODO(nweiz): Remove this once dart-lang/collection#289 is released.
  /// Like [Map.entries], but returns each entry as a record.
  Iterable<(K, V)> get pairs => entries.map((e) => (e.key, e.value));
}
