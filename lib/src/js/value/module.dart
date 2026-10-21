// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../../functions/color.dart' as color;
import '../../value.dart';
import '../reflection.dart';
import '../utils.dart';

/// The JavaScript `SassModule` class.
final JSClass moduleClass = () {
  var jsClass = createJSClass('sass.SassModule', (Object self) {
    jsThrow(
      JsError(
        'It is not possible to construct a SassModule through the JavaScript '
        'API',
      ),
    );
  });

  getJSClass(SassModule(color.module)).injectSuperclass(jsClass);
  return jsClass;
}();
