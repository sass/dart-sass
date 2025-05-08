// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../value.dart';

extension SassStringToJS on SassString {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassString>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassString>>(((
            [JSAny? textOrOptions, _ConstructorOptions? options]) =>
        textOrOptions.isA<JSString>()
            ? SassString((textOrOptions as JSString).toDart,
                    quotes: options?.quotes ?? true)
                .toJS
            : SassString.empty(
                quotes: (textOrOptions as _ConstructorOptions?)?.quotes ?? true,
              ).toJS).toJS)
      ..defineGetters({
        'text': (UnsafeDartWrapper<SassString> self) => self.toDart.text.toJS,
        'hasQuotes': (UnsafeDartWrapper<SassString> self) =>
            self.toDart.hasQuotes.toJS,
        'sassLength': (UnsafeDartWrapper<SassString> self) =>
            self.toDart.sassLength.toJS,
      })
      ..defineMethod(
        'sassIndexToStringIndex'.toJS,
        ((UnsafeDartWrapper<SassString> self,
                    UnsafeDartWrapper<Value> sassIndex, [String? name]) =>
                self.toDart.sassIndexToStringIndex(sassIndex.toDart, name))
            .toJSCaptureThis,
      );

    SassString.empty().toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassString> get toJS => toUnsafeWrapper;
}

extension type _ConstructorOptions._(JSObject _) implements JSObject {
  external bool? get quotes;
}
