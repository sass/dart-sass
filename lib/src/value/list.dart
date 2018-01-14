// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../utils.dart';
import '../visitor/interface/value.dart';
import '../value.dart';
import 'external/value.dart' as ext;

class SassList extends Value implements ext.SassList {
  final List<Value> contents;

  final ListSeparator separator;

  final bool hasBrackets;

  bool get isBlank => contents.every((element) => element.isBlank);

  List<Value> get asList => contents;

  int get lengthAsList => contents.length;

  const SassList.empty({ListSeparator separator, bool brackets: false})
      : contents = const [],
        separator = separator ?? ListSeparator.undecided,
        hasBrackets = brackets;

  SassList(Iterable<Value> contents, this.separator, {bool brackets: false})
      : contents = new List.unmodifiable(contents),
        hasBrackets = brackets {
    if (separator == ListSeparator.undecided && contents.length > 1) {
      throw new ArgumentError(
          "A list with more than one element must have an explicit separator.");
    }
  }

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitList(this);

  SassMap assertMap([String name]) =>
      contents.isEmpty ? const SassMap.empty() : super.assertMap(name);

  bool operator ==(other) =>
      (other is SassList &&
          other.separator == separator &&
          other.hasBrackets == hasBrackets &&
          listEquals(other.contents, contents)) ||
      (contents.isEmpty && other is SassMap && other.contents.isEmpty);

  int get hashCode => listHash(contents);
}

/// An enum of list separator types.
class ListSeparator {
  /// A space-separated list.
  static const space = const ListSeparator._("space", " ");

  /// A comma-separated list.
  static const comma = const ListSeparator._("comma", ",");

  /// A separator that hasn't yet been determined.
  ///
  /// Singleton lists and empty lists don't have separators defiend. This means
  /// that list functions will prefer other lists' separators if possible.
  static const undecided = const ListSeparator._("undecided", null);

  final String _name;

  /// The separator character.
  ///
  /// If the separator of a list has not been decided, this value will be
  /// `null`.
  final String separator;

  const ListSeparator._(this._name, this.separator);

  String toString() => _name;
}
