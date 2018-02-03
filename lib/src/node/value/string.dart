// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'dart:js_util';

import '../../value.dart';
import '../utils.dart';

@JS()
class _NodeSassString {
  external SassString get dartValue;
  external set dartValue(SassString dartValue);
}

/// Creates a new `sass.types.String` object wrapping [value].
Object newNodeSassString(SassString value) =>
    callConstructor(stringConstructor, [null, value]);

/// The JS constructor for the `sass.types.String` class.
final Function stringConstructor = createClass(
    (_NodeSassString thisArg, String value, [SassString dartValue]) {
  thisArg.dartValue = dartValue ?? new SassString(value, quotes: false);
}, {
  'getValue': (_NodeSassString thisArg) => thisArg.dartValue.text,
  'setValue': (_NodeSassString thisArg, String value) {
    thisArg.dartValue =
        new SassString(value, quotes: thisArg.dartValue.hasQuotes);
  },
  'toString': (_NodeSassString thisArg) => thisArg.dartValue.toString()
});
