// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../utils.dart';
import '../value.dart';

extension type JSSassString._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSSassString> jsClass = () {
    var jsClass = JSClass<JSSassString>(
        'sass.SassString',
        ((JSSassString self,
                [JSObject? textOrOptions, _ConstructorOptions? options]) =>
            switch (textOrOptions.asA<JSString>()) {
              var text? =>
                SassString(text.toDart, quotes: options?.quotes ?? true),
              _ => SassString.empty(
                  quotes:
                      (textOrOptions as _ConstructorOptions?)?.quotes ?? true,
                )
            }).toJS)
      ..defineGetters({
        'text': (JSSassString self) => self.toDart.text.toJS,
        'hasQuotes': (JSSassString self) => self.toDart.hasQuotes.toJS,
        'sassLength': (JSSassString self) => self.toDart.sassLength.toJS,
      })
      ..defineMethod(
        'sassIndexToStringIndex'.toJS,
        ((JSSassString self, JSValue sassIndex, [String? name]) =>
            self.toDart.sassIndexToStringIndex(sassIndex.toDart, name)).toJS,
      );

    SassString.empty().toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  SassString get toDart => this as SassString;
}

extension SassStringToJS on SassString {
  JSSassString get toJS => this as JSSassString;
}

@anonymous
extension type _ConstructorOptions._(JSObject _) implements JSObject {
  external bool? get quotes;
}
