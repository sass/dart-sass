// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'function.dart';

/// Sets the `toString()` function for [object] to [body].
///
/// Dart's JS interop doesn't currently let us set toString() for custom
/// classes, so we use this as a workaround.
void setToString(object, String body()) =>
    _setToString.call(object, allowInterop(body));

final _setToString =
    new JSFunction("object", "body", "object.toString = body;");

/// Throws [error] like JS would, without any Dart wrappers.
void jsThrow(error) => _jsThrow.call(error);

final _jsThrow = new JSFunction("error", "throw error;");
