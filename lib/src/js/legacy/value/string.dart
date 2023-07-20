// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../../value.dart';
import '../../reflection.dart';

@JS()
class _NodeSassString {
  external SassString get dartValue;
  external set dartValue(SassString dartValue);
}

/// Creates a new `sass.types.String` object wrapping [value].
Object newNodeSassString(SassString value) =>
    legacyStringClass.construct([null, value]);

/// The JS constructor for the `sass.types.String` class.
final JSClass legacyStringClass = createJSClass('sass.types.String',
    (_NodeSassString thisArg, String? value, [SassString? dartValue]) {
  // Either [dartValue] or [value] must be passed.
  thisArg.dartValue = dartValue ?? SassString(value!, quotes: false);
})
  ..defineMethods({
    'getValue': (_NodeSassString thisArg) => thisArg.dartValue.text,
    'setValue': (_NodeSassString thisArg, String value) {
      thisArg.dartValue = SassString(value, quotes: false);
    }
  });
