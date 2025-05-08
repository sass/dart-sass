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
import '../../util.dart';

extension type JSSassBoolean._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSBoolean> jsClass = () {
    var jsClass = JSClass<JSBoolean>('sass.SassBoolean', (JSBoolean self, [JSAny? _]) {
    JSError.throwLikeJS(
      JSError(
        "new sass.SassBoolean() isn't allowed.\n"
        "Use sass.sassTrue or sass.sassFalse instead.",
      ),
    );
  }.toJS);

  sassTrue.toJS.constructor.injectSuperclass(jsClass);

  return jsClass;
}();

  SassBoolean get toDart => this as SassBoolean;
}

extension SassBooleanToJS on SassBoolean {
  JSSassBoolean get toJS => this as JSSassBoolean;
}
