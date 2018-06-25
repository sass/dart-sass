// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS("Function")
class JSFunction implements Function {
  external JSFunction(String arg1, [String arg2, String arg3]);

  // Note that this just invokes the function with the given arguments, rather
  // than calling `Function.prototype.call()`. See sdk#31271.
  external call([arg1, arg2, arg3]);

  external apply(thisArg, [List args]);
}
