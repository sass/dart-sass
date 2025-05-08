// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';

extension SassBooleanToJS on SassBoolean {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassBoolean>> jsClass = () {
    // TODO - dart-lang/sdk#61249: define this inline when `Never` works as a JS
    // interop type.
    void constructor([JSAny? _]) {
      JSError.throwLikeJS(
        JSError(
          "new sass.SassBoolean() isn't allowed.\n"
          "Use sass.sassTrue or sass.sassFalse instead.",
        ),
      );
    }

    var jsClass = JSClass<UnsafeDartWrapper<SassBoolean>>(constructor.toJS);

    sassTrue.toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassBoolean> get toJS => toUnsafeWrapper;
}
