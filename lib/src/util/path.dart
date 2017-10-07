// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as path;

import '../io.dart';

/// A path context for the current operating system.
///
/// We define our own context rather than using the default one to work around
/// the issue that sdk#30098 fixes.
final p = new path.Context(
    style: isWindows ? path.Style.windows : path.Style.posix,
    current: currentPath);
