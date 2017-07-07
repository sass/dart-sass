// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS("Function")
class JSFunction {
  @JS("Function")
  external JSFunction(String arg1, [String arg2, String arg3]);

  external call(thisArg, [arg1, arg2]);
}
