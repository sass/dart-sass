// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../visitor/interface/value.dart';
import '../value.dart';

class SassMap extends Value {
  // TODO(nweiz): Use persistent data structures rather than copying here. We
  // need to preserve the order, which can be done by tracking an RRB vector of
  // keys along with the hash-mapped array trie representing the map.
  //
  // We may also want to fall back to a plain unmodifiable Map for small maps
  // (<32 items?).
  final Map<Value, Value> contents;

  ListSeparator get separator => ListSeparator.comma;

  List<SassList> get asList {
    var result = <SassList>[];
    contents.forEach((key, value) {
      result.add(new SassList([key, value], ListSeparator.space));
    });
    return result;
  }

  const SassMap.empty() : contents = const {};

  SassMap(Map<Value, Value> contents)
      : contents = new Map.unmodifiable(contents);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) => visitor.visitMap(this);

  SassMap assertMap([String name]) => this;

  bool operator ==(other) =>
      (other is SassMap &&
          const MapEquality().equals(other.contents, contents)) ||
      (contents.isEmpty && other is SassList && other.contents.isEmpty);

  int get hashCode => contents.isEmpty
      ? const SassList.empty().hashCode
      : const MapEquality().hash(contents);
}
