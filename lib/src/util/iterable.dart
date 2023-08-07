// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

extension IterableExtension<E> on Iterable<E> {
  /// Returns the first `T` returned by [callback] for an element of [iterable],
  /// or `null` if it returns `null` for every element.
  T? search<T>(T? Function(E element) callback) {
    for (var element in this) {
      if (callback(element) case var value?) return value;
    }
    return null;
  }

  /// Returns a view of this list that covers all elements except the last.
  ///
  /// Note this is only efficient for an iterable with a known length.
  Iterable<E> get exceptLast {
    var size = length - 1;
    if (size < 0) throw StateError('Iterable may not be empty');
    return take(size);
  }
}
