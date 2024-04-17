// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../../callable.dart';
import '../../value.dart';
import '../reflection.dart';
import '../utils.dart';

/// The JavaScript `SassMixin` class.
final JSClass mixinClass = () {
  var jsClass = createJSClass('sass.SassMixin', (Object self) {
    jsThrow(JsError(
        'It is not possible to construct a SassMixin through the JavaScript '
        'API'));
  });

  getJSClass(SassMixin(Callable('f', '', (_) => sassNull)))
      .injectSuperclass(jsClass);
  return jsClass;
}();
