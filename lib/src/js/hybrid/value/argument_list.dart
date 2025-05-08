// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../utils.dart';
import '../value.dart';

extension SassArgumentListToJS on SassArgumentList {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<UnsafeDartWrapper<SassArgumentList>> jsClass = () {
    var jsClass = JSClass<UnsafeDartWrapper<SassArgumentList>>((
      JSObject contents,
      JSObject keywords, [
      String? separator = ',',
    ]) {
      return SassArgumentList(
        contents.toDartList<UnsafeDartWrapper<Value>>().cast<Value>(),
        (ImmutableMap.isA(keywords)
                ? (keywords as ImmutableMap<JSString, UnsafeDartWrapper<Value>>)
                    .toDart
                : (keywords as JSRecord<UnsafeDartWrapper<Value>>).toDart)
            .cast<String, Value>(),
        parseSeparator(separator),
      ).toJS;
    }.toJS)
      ..defineGetter(
        'keywords'.toJS,
        (UnsafeDartWrapper<SassArgumentList> self) => self.toDart.keywords
            .cast<JSString, UnsafeDartWrapper<Value>>()
            .toJSImmutable,
      );

    SassArgumentList(const [], const {}, ListSeparator.comma)
        .toJS
        .constructor
        .injectSuperclass(jsClass);

    return jsClass;
  }();

  UnsafeDartWrapper<SassArgumentList> get toJS => toUnsafeWrapper;
}
