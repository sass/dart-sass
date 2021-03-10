// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

extension NullableExtension<T> on T /*?*/ {
  /// If [this] is `null`, returns `null`. Otherwise, runs [fn] and returns its
  /// result.
  ///
  /// Based on Rust's `Option.and_then`.
  V /*?*/ andThen<V>(V Function(T value) fn) {
    var self = this; // dart-lang/language#1520
    return self == null ? null : fn(self);
  }
}

extension NullableListExtension<T> on List<T> /*?*/ {
  /// If [this] is `null`, returns `null`. Otherwise, returns `this[index]`.
  ///
  /// This is the equivalent of `list?.[key]`, if such a thing existed.
  T /*?*/ andGet(int index) {
    var self = this;
    return self == null ? null : self[index];
  }
}

extension NullableMapExtension<K, V> on Map<K, V> /*?*/ {
  /// If [this] is `null`, returns `null`. Otherwise, returns `this[key]`.
  ///
  /// This is the equivalent of `map?.[key]`, if such a thing existed.
  V /*?*/ andGet(Object key) {
    var self = this;
    // TODO: no as
    return self == null ? null : self[key];
  }
}

extension SetExtension<T> on Set<T /*?*/ > {
  /// Destructively removes the `null` element from this set, if it exists, and
  /// returns a view of it casted to a non-nullable type.
  Set<T> removeNull() {
    this.remove(null);
    return this.cast<T>();
  }
}
