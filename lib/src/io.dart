// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/node.dart';
import 'utils.dart';

export 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/node.dart';

/// Returns whether the current operating system might be case-insensitive.
///
/// We can't know for sure because different Mac OS systems are configured
/// differently.
bool get couldBeCaseInsensitive => isWindows || isMacOS;

/// Returns `path` with the case updated to match the path's case on disk.
///
/// This only updates `path`'s basename. It always returns `path` as-is on
/// operating systems other than Windows or Mac OS, since they almost never uses
/// case-insensitive filesystems.
String realCasePath(String path) {
  // TODO(nweiz): Use an SDK function for this when dart-lang/sdk#35370 and/or
  // nodejs/node#24942 are fixed.

  if (!couldBeCaseInsensitive) return path;

  var basename = p.basename(path);
  var matches = listDir(p.dirname(path))
      .where((realPath) => equalsIgnoreCase(p.basename(realPath), basename))
      .toList();

  // If the file doesn't exist, or if there are multiple options (meaning the
  // filesystem isn't actually case-insensitive), return `path` as-is.
  if (matches.length != 1) return path;
  return matches.first;
}
