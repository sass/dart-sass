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
bool get _couldBeCaseInsensitive => isWindows || isMacOS;

/// Returns the canonical form of `path` on disk.
String canonicalize(String path) => _couldBeCaseInsensitive
    ? _realCasePath(p.absolute(p.normalize(path)))
    : p.canonicalize(path);

/// Returns `path` with the case updated to match the path's case on disk.
///
/// This only updates `path`'s basename. It always returns `path` as-is on
/// operating systems other than Windows or Mac OS, since they almost never use
/// case-insensitive filesystems.
String _realCasePath(String path) {
  // TODO(nweiz): Use an SDK function for this when dart-lang/sdk#35370 and/or
  // nodejs/node#24942 are fixed, or at least use FFI functions.

  if (!_couldBeCaseInsensitive) return path;

  var realCasePath = p.rootPrefix(path);
  for (var component in p.split(path.substring(realCasePath.length))) {
    var matches = listDir(realCasePath)
        .where((realPath) => equalsIgnoreCase(p.basename(realPath), component))
        .toList();

    realCasePath = matches.length != 1
        // If the file doesn't exist, or if there are multiple options (meaning
        // the filesystem isn't actually case-insensitive), use `component` as-is.
        ? p.join(realCasePath, component)
        : matches[0];
  }

  return realCasePath;
}
