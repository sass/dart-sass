// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../visitor/interface/value.dart';
import '../value.dart';

class SassMap extends Value {
  final Map<Value, Value> contents;

  SassMap(Map<Value, Value> contents)
      : contents = new Map.unmodifiable(contents);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) => visitor.visitMap(this);

  bool operator ==(other) =>
      other is SassMap && const MapEquality().equals(other.contents, contents);

  int get hashCode => const MapEquality().hash(contents);

  String toString() {
    return '(' + contents.keys.map((key) {
      return '$key: ${contents[key]}';
    }).join(', ') + ')';
  }
}
