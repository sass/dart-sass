// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart';
import '../immutable.dart';
import '../reflection.dart';
import '../utils.dart';

/// The JavaScript `SassArgumentList` class.
final JSClass argumentListClass = () {
  var jsClass = createJSClass('sass.SassArgumentList',
      (Object self, Object contents, Object keywords, [String? separator]) {
    return SassArgumentList(
        jsToDartList(contents).cast<Value>(),
        (isImmutableMap(keywords)
                ? immutableMapToDartMap(keywords as ImmutableMap)
                : objectToMap(keywords))
            .cast<String, Value>(),
        jsToDartSeparator(separator));
  });

  jsClass.defineGetter('keywords',
      (SassArgumentList self) => dartMapToImmutableMap(self.keywords));

  getJSClass(SassArgumentList([], {}, ListSeparator.undecided))
      .injectSuperclass(jsClass);
  return jsClass;
}();
