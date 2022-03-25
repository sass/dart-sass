// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../visitor/interface/value.dart';
import '../value.dart';
import '../utils.dart';

/// A SassScript map.
///
/// {@category Value}
@sealed
class SassMap extends Value {
  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

  // TODO(nweiz): Use persistent data structures rather than copying here. We
  // need to preserve the order, which can be done by tracking an RRB vector of
  // keys along with the hash-mapped array trie representing the map.
  //
  // We may also want to fall back to a plain unmodifiable Map for small maps
  // (<32 items?).
  /// The contents of the map.
  Map<Value, Value> get contents => _contents;
  final Map<Value, Value> _contents;

  ListSeparator get separator =>
      contents.isEmpty ? ListSeparator.undecided : ListSeparator.comma;

  List<Value> get asList {
    var result = <Value>[];
    contents.forEach((key, value) {
      result.add(SassList([key, value], ListSeparator.space));
    });
    return result;
  }

  /// @nodoc
  @internal
  int get lengthAsList => contents.length;

  /// Returns an empty map.
  const SassMap.empty() : _contents = const {};

  SassMap(Map<Value, Value> contents) : _contents = Map.unmodifiable(contents);

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitMap(this);

  SassMap assertMap([String? name]) => this;

  SassMap tryMap() => this;

  bool operator ==(Object other) =>
      (other is SassMap && mapEquals(other.contents, contents)) ||
      (contents.isEmpty && other is SassList && other.asList.isEmpty);

  int get hashCode =>
      contents.isEmpty ? const SassList.empty().hashCode : mapHash(contents);
}
