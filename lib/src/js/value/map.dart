// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../../value.dart';
import '../immutable.dart';
import '../reflection.dart';

/// The JavaScript `SassMap` class.
final JSClass mapClass = () {
  var jsClass = createJSClass(
      'sass.SassMap',
      (Object self, [ImmutableMap? contents]) => contents == null
          ? const SassMap.empty()
          : SassMap(immutableMapToDartMap(contents).cast<Value, Value>()));

  jsClass.defineGetter(
      'contents', (SassMap self) => dartMapToImmutableMap(self.contents));

  jsClass.defineMethod('get', (SassMap self, Object indexOrKey) {
    if (indexOrKey is num) {
      var index = indexOrKey.floor();
      if (index < 0) index = self.lengthAsList + index;
      if (index < 0 || index >= self.lengthAsList) return undefined;

      var entry = self.contents.entries.elementAt(index);
      return SassList([entry.key, entry.value], ListSeparator.space);
    } else {
      return self.contents[indexOrKey] ?? undefined;
    }
  });

  getJSClass(const SassMap.empty()).injectSuperclass(jsClass);
  return jsClass;
}();
