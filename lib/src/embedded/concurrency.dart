// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:ffi';

/// More than MaxMutatorThreadCount isolates in the same isolate group
/// can deadlock the Dart VM.
///
/// See https://github.com/sass/dart-sass/pull/2019
int get concurrencyLimit => sizeOf<IntPtr>() <= 4 ? 7 : 15;
