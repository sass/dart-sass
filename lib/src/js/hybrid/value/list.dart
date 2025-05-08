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

extension type JSSassList._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSSassList> jsClass = () {
    var jsClass = JSClass<JSSassList>(
        'sass.SassList',
        (
          JSSassList self, [
          JSObject? contentsOrOptions,
          _ConstructorOptions? options,
        ]) {
          List<Value> contents;
          if (ImmutableList.isA(contentsOrOptions)) {
            contents = (contentsOrOptions as ImmutableList<JSValue>)
                .toDart
                .cast<Value>();
          } else if (contentsOrOptions.asA<JSArray<JSValue>>()
              case var array?) {
            contents = array.toDart.cast<Value>();
          } else {
            contents = [];
            options = contentsOrOptions as _ConstructorOptions?;
          }

          return SassList(
            contents,
            options == null || options.separator.isUndefined
                ? ListSeparator.comma
                : parseSeparator(options.separator?.toDart),
            brackets: options?.brackets ?? false,
          );
        }.toJS)
      ..defineMethod(
          'get'.toJS,
          (JSSassList jsSelf, num indexFloat) {
            var self = jsSelf.toDart;
            var index = indexFloat.floor();
            if (index < 0) index = self.asList.length + index;
            if (index < 0 || index >= self.asList.length) return undefined;
            return self.asList[index].toJS;
          }.toJS);

    const SassList.empty().toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  SassList get toDart => this as SassList;
}

extension SassListToJS on SassList {
  JSSassList get toJS => this as JSSassList;
}

@anonymous
extension type _ConstructorOptions(JSObject _) implements JSObject {
  external JSString? get separator;
  external bool? get brackets;
}
