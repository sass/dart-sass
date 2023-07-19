// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_util';

import 'package:sass/src/node/utils.dart';

import '../../value.dart';
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
///
/// If [object] is a JS error, throws it.
Value unwrapValue(Object? object) {
  if (object != null) {
    if (object is Value) return object;

    // TODO(nweiz): Remove this ignore and add an explicit type argument once we
    // support only Dart SDKs >= 2.15.
    // ignore: inference_failure_on_function_invocation
    var value = getProperty(object, 'dartValue');
    if (value != null && value is Value) return value;
    if (isJSError(object)) throw object;
  }
  throw "$object must be a Sass value type.";
}

/// Wraps a [Value] in a wrapper that exposes the Node Sass API for that value.
Object wrapValue(Value value) => switch (value) {
      SassColor() => newNodeSassColor(value),
      SassList() => newNodeSassList(value),
      SassMap() => newNodeSassMap(value),
      SassNumber() => newNodeSassNumber(value),
      SassString() => newNodeSassString(value),
      _ => value
    };
