// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../value.dart';
import '../reflection.dart';

/// The JavaScript `SassString` class.
final JSClass stringClass = () {
  var jsClass = createJSClass(
      'sass.SassString',
      (Object self, [Object? textOrOptions, _ConstructorOptions? options]) =>
          textOrOptions is String
              ? SassString(textOrOptions, quotes: options?.quotes ?? true)
              : SassString.empty(
                  quotes:
                      (textOrOptions as _ConstructorOptions?)?.quotes ?? true));

  jsClass.defineGetters({
    'text': (SassString self) => self.text,
    'hasQuotes': (SassString self) => self.hasQuotes,
    'sassLength': (SassString self) => self.sassLength,
  });

  jsClass.defineMethod(
      'sassIndexToStringIndex',
      (SassString self, Value sassIndex, [String? name]) =>
          self.sassIndexToStringIndex(sassIndex, name));

  getJSClass(SassString.empty()).injectSuperclass(jsClass);
  return jsClass;
}();

@JS()
@anonymous
class _ConstructorOptions {
  external bool? get quotes;
}
