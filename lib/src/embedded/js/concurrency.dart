// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

@JS('os.cpus')
external JSArray _cpus();

int get concurrencyLimit => _cpus().length;
