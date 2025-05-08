// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js_core/js_core.dart';

import '../utils.dart';

/// Throws a JSError if [scheme] isn't a valid URL scheme.
void validateUrlScheme(String scheme) {
  if (!isValidUrlScheme(scheme)) {
    JSError.throwLikeJS(
      JSError('"$scheme" isn\'t a valid URL scheme (for example "file").'),
    );
  }
}
