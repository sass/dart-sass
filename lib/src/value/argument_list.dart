// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../value.dart';

/// A SassScript argument list.
///
/// An argument list comes from a rest argument. It's distinct from a normal
/// [SassList] in that it may contain a keyword map as well as the positional
/// arguments.
@sealed
class SassArgumentList extends SassList {
  /// The keyword arguments attached to this argument list.
  ///
  /// The argument names don't include `$`.
  Map<String, Value> get keywords {
    _wereKeywordsAccessed = true;
    return _keywords;
  }

  final Map<String, Value> _keywords;

  /// Whether [keywords] has been accessed.
  ///
  /// This is used to determine whether to throw an exception about passing
  /// unexpected keywords.
  ///
  /// @nodoc
  @internal
  bool get wereKeywordsAccessed => _wereKeywordsAccessed;
  var _wereKeywordsAccessed = false;

  SassArgumentList(Iterable<Value> contents, Map<String, Value> keywords,
      ListSeparator separator)
      : _keywords = Map.unmodifiable(keywords),
        super(contents, separator);
}
