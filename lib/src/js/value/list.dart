// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:node_interop/js.dart';

import '../../value.dart';
import '../immutable.dart';
import '../reflection.dart';
import '../utils.dart';

/// The JavaScript `SassList` class.
final JSClass listClass = () {
  var jsClass = createJSClass('sass.SassList', (Object self,
      [Object? contentsOrOptions, _ConstructorOptions? options]) {
    List<Value> contents;
    if (isImmutableList(contentsOrOptions)) {
      contents = (contentsOrOptions as ImmutableList).toArray().cast<Value>();
    } else if (contentsOrOptions is List) {
      contents = contentsOrOptions.cast<Value>();
    } else {
      contents = [];
      options = contentsOrOptions as _ConstructorOptions?;
    }

    return SassList(
        contents,
        options == null || isUndefined(options.separator)
            ? ListSeparator.comma
            : jsToDartSeparator(options.separator),
        brackets: options?.brackets ?? false);
  });

  jsClass.defineMethod('get', (Value self, num indexFloat) {
    var index = indexFloat.floor();
    if (index < 0) index = self.asList.length + index;
    if (index < 0 || index >= self.asList.length) return undefined;
    return self.asList[index];
  });

  getJSClass(const SassList.empty()).injectSuperclass(jsClass);
  return jsClass;
}();

@JS()
@anonymous
class _ConstructorOptions {
  external String? get separator;
  external bool? get brackets;
}
