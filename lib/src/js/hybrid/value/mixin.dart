// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../callable.dart';
import '../../../value.dart';
import '../../extension/class.dart';

extension SassMixinToJS on SassMixin {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassMixin>> jsClass = () {
    // TODO - dart-lang/sdk#61249: define this inline when `Never` works as a JS
    // interop type.
    void constructor() {
      JSError.throwLikeJS(
        JSError(
          'It is not possible to construct a SassMixin through the JavaScript '
          'API',
        ),
      );
    }

    var jsClass = JSClass<UnsafeDartWrapper<SassMixin>>(constructor.toJS);

    SassMixin(Callable('f', '', (_) => sassNull))
        .toJS
        .constructor
        .injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassMixin> get toJS => toUnsafeWrapper;
}
