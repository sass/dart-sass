// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../compile_stylesheet.dart';

/// We don't currently support concurrent compilation in JS.
///
/// In the future, we could add support using web workers.
final compileStylesheetConcurrently = compileStylesheet;
