// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../callable.dart';
import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

extension type JSSassMixin._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSMixin> jsClass = () {
    var jsClass = JSClass<JSMixin>('sass.SassMixin', (JSMixin self) {
    JSError.throwLikeJS(
      JSError(
        'It is not possible to construct a SassMixin through the JavaScript '
        'API',
      ),
    );
  }.toJS);

  SassMixin(Callable('f', '', (_) => sassNull)).toJS.constructor.injectSuperclass(jsClass);

  return jsClass;
}();

  SassMixin get toDart => this as SassMixin;
}

extension SassMixinToJS on SassMixin {
  JSSassMixin get toJS => this as JSSassMixin;
}
