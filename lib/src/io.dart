// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/node.dart';
import 'utils.dart';
import 'util/character.dart';

export 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/node.dart';

/// A cache of return values for directories in [_realCasePath].
final _realCaseCache = <String, String>{};

/// Returns whether the current operating system might be case-insensitive.
///
/// We can't know for sure because different Mac OS systems are configured
/// differently.
bool get _couldBeCaseInsensitive => isWindows || isMacOS;

/// Returns the canonical form of `path` on disk.
String canonicalize(String /*!*/ path) => _couldBeCaseInsensitive
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

  if (isWindows) {
    // Drive names are *always* case-insensitive, so convert them to uppercase.
    var prefix = p.rootPrefix(path);
    if (prefix.isNotEmpty && isAlphabetic(prefix.codeUnitAt(0))) {
      path = prefix.toUpperCase() + path.substring(prefix.length);
    }
  }

  String helper(String path) {
    var dirname = p.dirname(path);
    if (dirname == path) return path;

    return _realCaseCache.putIfAbsent(path, () {
      var realDirname = helper(dirname);
      var basename = p.basename(path);

      try {
        var matches = listDir(realDirname)
            .where(
                (realPath) => equalsIgnoreCase(p.basename(realPath), basename))
            .toList();

        return matches.length != 1
            // If the file doesn't exist, or if there are multiple options (meaning
            // the filesystem isn't actually case-insensitive), use `basename`
            // as-is.
            ? p.join(realDirname, basename)
            : matches[0];
      } on FileSystemException catch (_) {
        // If there's an error listing a directory, it's likely because we're
        // trying to reach too far out of the current directory into something
        // we don't have permissions for. In that case, just assume we have the
        // real path.
        return path;
      }
    });
  }

  return helper(path);
}
