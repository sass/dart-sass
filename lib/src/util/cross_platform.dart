// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

export 'cross_platform/interface.dart'
    if (dart.library.io) 'cross_platform/vm.dart'
    if (dart.library.js) 'cross_platform/js.dart';
