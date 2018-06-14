// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart' as internal;
import '../../value.dart' show ListSeparator;
import 'value.dart';

/// A SassScript argument list.
///
/// An argument list comes from a rest argument. It's distinct from a normal
/// [SassList] in that it may contain a keyword map as well as the positional
/// arguments.
abstract class SassArgumentList extends SassList {
  /// The keyword arguments attached to this argument list.
  ///
  /// The argument names don't include `$`.
  Map<String, Value> get keywords;

  factory SassArgumentList(Iterable<Value> contents,
          Map<String, Value> keywords, ListSeparator separator) =>
      new internal.SassArgumentList(
          contents.cast(), keywords.cast(), separator);
}
