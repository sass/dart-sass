// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import '../value.dart';
import 'value/color.dart';
import 'value/list.dart';
import 'value/map.dart';
import 'value/number.dart';
import 'value/string.dart';

export 'value/boolean.dart';
export 'value/color.dart';
export 'value/list.dart';
export 'value/map.dart';
export 'value/null.dart';
export 'value/number.dart';
export 'value/string.dart';

/// Unwraps a value wrapped with [wrapValue].
Value unwrapValue(object) {
  if (object != null) {
    if (object is Value) return object;
    var value = getProperty(object, 'dartValue');
    if (value != null && value is Value) return value;
  }
  throw "$object must be a Sass value type.";
}

/// Wraps a [Value] in a wrapper that exposes the Node Sass API for that value.
Object wrapValue(Value value) {
  if (value is SassColor) return newNodeSassColor(value);
  if (value is SassList) return newNodeSassList(value);
  if (value is SassMap) return newNodeSassMap(value);
  if (value is SassNumber) return newNodeSassNumber(value);
  if (value is SassString) return newNodeSassString(value);
  return value;
}
