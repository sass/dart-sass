// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

export 'legacy_node/interface.dart'
    if (dart.library.js) 'legacy_node/implementation.dart';
