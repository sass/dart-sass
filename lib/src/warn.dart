// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

/// Prints a warning message associated with the current `@import` or function
/// call.
///
/// If [deprecation] is `true`, the warning is emitted as a deprecation warning.
///
/// This may only be called within a custom function or importer callback.
void warn(String message, {bool deprecation = false}) {
  var warnDefinition = Zone.current[#_warn];

  if (warnDefinition == null) {
    throw ArgumentError(
        "warn() may only be called within a custom function or importer "
        "callback.");
  }

  warnDefinition(message, deprecation);
}

/// Runs [callback] with [warn] as the definition for the top-level `warn()` function.
///
/// This is zone-based, so if [callback] is asynchronous [warn] is set for the
/// duration of that callback.
T withWarnCallback<T>(
    void warn(String message, bool deprecation), T callback()) {
  return runZoned(() {
    return callback();
  }, zoneValues: {#_warn: warn});
}
