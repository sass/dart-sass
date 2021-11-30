// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../utils.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript list.
///
/// {@category Value}
@sealed
class SassList extends Value {
  // TODO(nweiz): Use persistent data structures rather than copying here. An
  // RRB vector should fit our use-cases well.
  //
  // We may also want to fall back to a plain unmodifiable List for small lists
  // (<32 items?).
  final List<Value> _contents;

  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

  ListSeparator get separator => _separator;
  final ListSeparator _separator;

  bool get hasBrackets => _hasBrackets;
  final bool _hasBrackets;

  /// @nodoc
  @internal
  bool get isBlank => asList.every((element) => element.isBlank);

  List<Value> get asList => _contents;

  /// @nodoc
  @internal
  int get lengthAsList => asList.length;

  /// Returns an empty list with the given [separator] and [brackets].
  ///
  /// The [separator] defaults to [ListSeparator.undecided], and [brackets] defaults to `false`.
  const SassList.empty({ListSeparator? separator, bool brackets = false})
      : _contents = const [],
        _separator = separator ?? ListSeparator.undecided,
        _hasBrackets = brackets;

  /// Returns an empty list with the given [separator] and [brackets].
  SassList(Iterable<Value> contents, this._separator, {bool brackets = false})
      : _contents = List.unmodifiable(contents),
        _hasBrackets = brackets {
    if (separator == ListSeparator.undecided && asList.length > 1) {
      throw ArgumentError(
          "A list with more than one element must have an explicit separator.");
    }
  }

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitList(this);

  SassMap assertMap([String? name]) =>
      asList.isEmpty ? const SassMap.empty() : super.assertMap(name);

  SassMap? tryMap() => asList.isEmpty ? const SassMap.empty() : null;

  bool operator ==(Object other) =>
      (other is SassList &&
          other.separator == separator &&
          other.hasBrackets == hasBrackets &&
          listEquals(other.asList, asList)) ||
      (asList.isEmpty && other is SassMap && other.asList.isEmpty);

  int get hashCode => listHash(asList);
}

/// An enum of list separator types.
///
/// {@category Value}
@sealed
class ListSeparator {
  /// A space-separated list.
  static const space = ListSeparator._("space", " ");

  /// A comma-separated list.
  static const comma = ListSeparator._("comma", ",");

  /// A slash-separated list.
  static const slash = ListSeparator._("slash", "/");

  /// A separator that hasn't yet been determined.
  ///
  /// Singleton lists and empty lists don't have separators defined. This means
  /// that list functions will prefer other lists' separators if possible.
  static const undecided = ListSeparator._("undecided", null);

  final String _name;

  /// The separator character.
  ///
  /// If the separator of a list has not been decided, this value will be
  /// `null`.
  final String? separator;

  const ListSeparator._(this._name, this.separator);

  String toString() => _name;
}
