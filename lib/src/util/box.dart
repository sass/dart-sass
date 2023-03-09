// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// An unmodifiable reference to a value that may be mutated elsewhere.
///
/// This uses reference equality based on the underlying [ModifiableBox], even
/// when the underlying type uses value equality.
class Box<T> {
  final ModifiableBox<T> _inner;

  T get value => _inner.value;

  Box._(this._inner);

  bool operator ==(Object? other) => other is Box<T> && other._inner == _inner;

  int get hashCode => _inner.hashCode;
}

/// A mutable reference to a (presumably immutable) value.
///
/// This always uses reference equality, even when the underlying type uses
/// value equality.
class ModifiableBox<T> {
  T value;

  ModifiableBox(this.value);

  /// Returns an unmodifiable reference to this box.
  ///
  /// The underlying modifiable box may still be modified.
  Box<T> seal() => Box._(this);
}
