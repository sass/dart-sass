// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS("Function")
class JSFunction {
  /// Creates a [JS function].
  ///
  /// The **last** argument is the function body. The other arguments become the
  /// function's parameters.
  ///
  /// The function body must declare a `return` statement in order to return a
  /// value, otherwise it returns [JSNull].
  ///
  /// Note: The function body must be compatible with Node 12. Null coalescing
  /// and optional chaining features are not supported.
  ///
  /// Examples:
  /// ```dart
  /// var sum = JSFunction('a', 'b', 'return a + b');
  /// sum.call(13, 29) as int; // 42
  ///
  /// var isJsString = JSFunction('a', 'return typeof a === "string"');
  /// isJsString.call(42) as bool;   // false
  /// isJsString.call('42') as bool; // true
  ///
  /// var sayHi = JSFunction('console.log("Hi!")');
  /// sayHi.call(); // Logs "Hi!"
  /// ```
  ///
  /// [JS Function]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/Function#syntax
  external JSFunction(String arg1, [String? arg2, String? arg3]);

  // Note that this just invokes the function with the given arguments, rather
  // than calling `Function.prototype.call()`. See sdk#31271.
  external Object? call([Object? arg1, Object? arg2, Object? arg3]);

  external Object? apply(Object thisArg, [List<Object>? args]);
}
