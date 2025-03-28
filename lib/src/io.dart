// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:path/path.dart' as p;

import 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/js.dart';
import 'utils.dart';
import 'util/character.dart';

export 'io/interface.dart'
    if (dart.library.io) 'io/vm.dart'
    if (dart.library.js) 'io/js.dart';

/// A cache of return values for directories in [_realCasePath].
final _realCaseCache = <String, String>{};

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
/// This always returns `path` as-is on operating systems other than Windows or
/// Mac OS, since they almost never use case-insensitive filesystems.
String _realCasePath(String path) {
  // TODO(nweiz): Use an SDK function for this when dart-lang/sdk#35370 and/or
  // nodejs/node#24942 are fixed, or at least use FFI functions.

  if (!_couldBeCaseInsensitive) return path;

  if (isWindows) {
    // Drive names are *always* case-insensitive, so convert them to uppercase.
    var prefix = p.rootPrefix(path);
    if (prefix.isNotEmpty && prefix.codeUnitAt(0).isAlphabetic) {
      path = prefix.toUpperCase() + path.substring(prefix.length);
    }
  }

  String helper(String path, [String? realPath]) {
    var dirname = p.dirname(path);
    if (dirname == path) return path;

    return _realCaseCache.putIfAbsent(path, () {
      // If the path isn't a symlink, we can use the libraries' `realpath()`
      // functions to get its actual basename much more efficiently than listing
      // all its siblings.
      if (!linkExists(path)) {
        // Don't recompute the real path if it was already computed for a child
        // and we haven't seen any symlinks between that child and this directory.
        String realPathNonNull;
        try {
          realPathNonNull = realPath ?? realpath(path);
        } on FileSystemException {
          // If we can't get the realpath, that probably means the file doesn't
          // exist. Rather than throwing an error about symlink resolution,
          // return the non-existent path and let it throw whatever use-time
          // error it's going to throw.
          return path;
        }
        return p.join(helper(dirname, p.dirname(realPathNonNull)),
            p.basename(realPathNonNull));
      }

      var realDirname = helper(dirname);
      var basename = p.basename(path);
      try {
        var matches = listDir(realDirname)
            .where(
              (realPath) => equalsIgnoreCase(p.basename(realPath), basename),
            )
            .toList();

        return switch (matches) {
          [var match] => match,
          // If the file doesn't exist, or if there are multiple options
          // (meaning the filesystem isn't actually case-insensitive), use
          // `basename` as-is.
          _ => p.join(realDirname, basename),
        };
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
