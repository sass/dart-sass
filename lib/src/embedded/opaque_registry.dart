// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// A registry of some `T` indexed by ID so that the host can invoke
/// them.
final class OpaqueRegistry<T> {
  /// Instantiations of `T` that have been sent to the host.
  ///
  /// The values are located at indexes in the list matching their IDs.
  final _elementsById = <T>[];

  /// A reverse map from elements to their indexes in [_elementsById].
  final _idsByElement = <T, int>{};

  /// Converts an element of type `T` to a protocol buffer to send to the host.
  int protofy(T element) {
    var id = _idsByElement.putIfAbsent(element, () {
      _elementsById.add(element);
      return _elementsById.length - 1;
    });

    return id;
  }

  /// Returns the compiler-side element associated with [id].
  ///
  /// If no such element exists, returns `null`.
  T? operator [](int id) => _elementsById[id];
}
