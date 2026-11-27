// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

@JS('os.availableParallelism')
external JSNumber _availableParallelism();

int get concurrencyLimit => _availableParallelism().toDartInt;
