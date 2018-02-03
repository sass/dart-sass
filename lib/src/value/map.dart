// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../visitor/interface/value.dart';
import '../value.dart';
import 'external/value.dart' as ext;

class SassMap extends Value implements ext.SassMap {
  final Map<Value, Value> contents;

  ListSeparator get separator => ListSeparator.comma;

  List<Value> get asList {
    var result = <Value>[];
    contents.forEach((key, value) {
      result.add(new SassList([key, value], ListSeparator.space));
    });
    return result;
  }

  int get lengthAsList => contents.length;

  /// Returns an empty map.
  const SassMap.empty() : contents = const {};

  SassMap(Map<Value, Value> contents)
      : contents = new Map.unmodifiable(contents);

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitMap(this);

  SassMap assertMap([String name]) => this;

  bool operator ==(other) =>
      (other is SassMap &&
          const MapEquality().equals(other.contents, contents)) ||
      (contents.isEmpty && other is SassList && other.asList.isEmpty);

  int get hashCode => contents.isEmpty
      ? const SassList.empty().hashCode
      : const MapEquality().hash(contents);
}
