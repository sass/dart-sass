// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import 'package:collection/collection.dart';

import '../utils.dart';
import '../value.dart';
import 'external/value.dart' as ext;

class SassArgumentList extends SassList implements ext.SassArgumentList {
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
  /// **Note:** this function should not be called outside the `sass` package.
  /// It's not guaranteed to be stable across versions.
  bool get wereKeywordsAccessed => _wereKeywordsAccessed;
  var _wereKeywordsAccessed = false;

  SassArgumentList(Iterable<Value> contents, Map<String, Value> keywords,
      ListSeparator separator)
      : _keywords = new UnmodifiableMapView(normalizedMap(keywords)),
        super(contents, separator);
}
