// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// A class for efficiently adding elements to a list whose final length is
/// known in advance.
class FixedLengthListBuilder<T> {
  /// The list to which elements are being added.
  final List<T> _list;

  /// The index at which to add the next element to the list.
  ///
  /// This is set to -1 once the list has been returned.
  var _index = 0;

  /// Creates a new builder that creates a list of length [length].
  FixedLengthListBuilder(int length) : _list = List(length);

  /// Adds [element] to the next available space in the list.
  ///
  /// This may only be called if [build] has not yet been called, and if the
  /// list is not yet full.
  void add(T element) {
    _checkUnbuilt();
    _list[_index] = element;
    _index++;
  }

  /// Adds all elements in [elements] to the next available spaces in the list.
  ///
  /// This may only be called if [build] has not yet been called, and if the
  /// list has room for all of [elements].
  void addAll(Iterable<T> elements) {
    _checkUnbuilt();
    _list.setAll(_index, elements);
    _index += elements.length;
  }

  /// Adds the elements from [start] (inclusive) to [end] (exclusive) of
  /// [elements] to the next available spaces in the list.
  ///
  /// The [end] defaults to `elements.length`.
  ///
  /// This may only be called if [build] has not yet been called, and if the
  /// list has room for all the elements to add.
  void addRange(Iterable<T> elements, int start, [int end]) {
    _checkUnbuilt();
    var length = (end ?? elements.length) - start;
    _list.setRange(_index, _index + length, elements, start);
    _index += length;
  }

  /// Returns the mutable, fixed-length built list.
  ///
  /// Any spaces in the list that haven't had elements added explicitly will be
  /// `null`. This may only be called once.
  List<T> build() {
    _checkUnbuilt();
    _index = -1;
    return _list;
  }

  /// Throws a [StateError] if [build] has been called already.
  void _checkUnbuilt() {
    if (_index == -1) throw StateError("build() has already been called.");
  }
}
