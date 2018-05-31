// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as path;

import '../io.dart';

/// A path context for the current operating system.
///
/// We define our own context rather than using the default one to work around
/// the issue that sdk#30098 fixes.
path.Context get p {
  if (_p != null && _p.current == currentPath) return _p;
  _p = new path.Context(
      style: isWindows ? path.Style.windows : path.Style.posix,
      current: currentPath);
  return _p;
}

path.Context _p;

/// A path context for working with URLs.
path.Context get pUrl => path.url;
