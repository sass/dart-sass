// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../../ast/sass/argument_list.dart';
import '../../../value.dart';
import '../../../util/nullable.dart';
import '../../extension/class.dart';
import '../../immutable.dart';
import '../../util.dart';

extension type JSSassArgumentList._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static final JSClass<JSSassArgumentList> jsClass = () {
    var jsClass = JSClass<JSSassArgumentList>(
        'sass.SassArgumentList',
        (
          JSSassArgumentList self,
          JSObject contents,
          JSObject keywords, [
          String? separator = ',',
        ]) {
          return SassArgumentList(
            contents.toDartList<JSValue>().cast<Value>(),
            (ImmutableMap.isA(keywords)
                    ? (keywords as ImmutableMap<String, JSValue>).toDart
                    : (keywords as JSRecord<JSValue>).toDartMap)
                .cast<String, Value>(),
            jsToDartSeparator(separator),
          ).toJS;
        }.toJS)
      ..defineGetter(
        'keywords',
        (JSSassArgumentList self) => self.toDart.keywords.toImmutableMap,
      );

    SassArgumentList.bogus.toJS.constructor.injectSuperclass(jsClass);

    return jsClass;
  }();

  SassArgumentList get toDart => this as SassArgumentList;
}

extension SassArgumentListToJS on SassArgumentList {
  JSSassArgumentList get toJS => this as JSSassArgumentList;
}
