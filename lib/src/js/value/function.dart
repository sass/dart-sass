// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../../callable.dart';
import '../../value.dart';
import '../reflection.dart';
import '../utils.dart';

/// The JavaScript `SassFunction` class.
final JSClass functionClass = () {
  var jsClass = createJSClass('sass.SassFunction',
      (Object self, String signature, Value Function(List<Value>) callback) {
    var paren = signature.indexOf('(');
    if (paren == -1 || !signature.endsWith(')')) {
      jsThrow(JsError(
          'Invalid signature for new sass.SassFunction(): "$signature"'));
    }

    return SassFunction(Callable(signature.substring(0, paren),
        signature.substring(paren + 1, signature.length - 1), callback));
  });

  getJSClass(SassFunction(Callable('f', '', (_) => sassNull)))
      .injectSuperclass(jsClass);
  return jsClass;
}();
