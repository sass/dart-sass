// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../utils.dart';
import '../value.dart';

class SassArgumentList extends SassList {
  final Map<String, Value> _keywords;

  bool get wereKeywordsAccessed => _wereKeywordsAccessed;
  var _wereKeywordsAccessed = false;

  Map<String, Value> get keywords {
    _wereKeywordsAccessed = true;
    return _keywords;
  }

  SassArgumentList(Iterable<Value> contents, Map<String, Value> keywords,
      ListSeparator separator)
      : _keywords = new UnmodifiableMapView(normalizedMap()..addAll(keywords)),
        super(contents, separator);
}
