// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../../value.dart' as internal;
import '../../value.dart' show ListSeparator;
import 'value.dart';

/// A SassScript list.
abstract class SassList extends Value {
  // TODO(nweiz): Use persistent data structures rather than copying here. An
  // RRB vector should fit our use-cases well.
  //
  // We may also want to fall back to a plain unmodifiable List for small lists
  // (<32 items?).
  /// The contents of the list.
  List<Value> get contents;

  ListSeparator get separator;

  bool get hasBrackets;

  /// Returns an empty list with the given [separator] and [brackets].
  ///
  /// The [separator] defaults to [ListSeparator.undecided], and [brackets] defaults to `false`.
  const factory SassList.empty({ListSeparator separator, bool brackets}) =
      internal.SassList.empty;

  /// Returns an empty list with the given [separator] and [brackets].
  factory SassList(Iterable<Value> contents, ListSeparator separator,
          {bool brackets: false}) =>
      new internal.SassList(DelegatingIterable.typed(contents), separator,
          brackets: brackets);
}
