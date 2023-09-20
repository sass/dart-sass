// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:node_interop/js.dart';

import '../../js/utils.dart';
import '../utils.dart';

/// Throws a JsError if [scheme] isn't a valid URL scheme.
void validateUrlScheme(String scheme) {
  if (!isValidUrlScheme(scheme)) {
    jsThrow(
        JsError('"$scheme" isn\'t a valid URL scheme (for example "file").'));
  }
}
