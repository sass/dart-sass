// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart' as internal;
import 'value.dart';

/// A SassScript map.
abstract class SassMap extends Value {
  // TODO(nweiz): Use persistent data structures rather than copying here. We
  // need to preserve the order, which can be done by tracking an RRB vector of
  // keys along with the hash-mapped array trie representing the map.
  //
  // We may also want to fall back to a plain unmodifiable Map for small maps
  // (<32 items?).
  /// The contents of the map.
  Map<Value, Value> get contents;

  /// Returns an empty map.
  const factory SassMap.empty() = internal.SassMap.empty;

  factory SassMap(Map<Value, Value> contents) =>
      new internal.SassMap(contents.cast());
}
