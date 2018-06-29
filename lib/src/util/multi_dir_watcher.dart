// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:async/async.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

import '../io.dart';

/// Watches multiple directories which may change over time recursively for changes.
///
/// This ensures that each directory is only watched once, even if one is a
/// parent of another.
class MultiDirWatcher {
  /// A map from paths to the event streams for those paths.
  ///
  /// No key in this map is a parent directories of any other key in this map.
  final _watchers = <String, Stream<WatchEvent>>{};

  /// The stream of events from all directories that are being watched.
  Stream<WatchEvent> get events => _group.stream;
  final _group = new StreamGroup<WatchEvent>();

  /// Whether to manually check the filesystem for changes periodically.
  final bool _poll;

  /// Creates a [MultiDirWatcher].
  ///
  /// If [poll] is `true`, this manually checks the filesystem for changes
  /// periodically rather than using a native filesystem monitoring API.
  MultiDirWatcher({bool poll: false}) : _poll = poll;

  /// Watches [directory] for changes.
  ///
  /// Returns a [Future] that completes when [events] is ready to emit events
  /// from [directory].
  Future watch(String directory) {
    var isParentOfExistingDir = false;
    for (var existingDir in _watchers.keys.toList()) {
      if (!isParentOfExistingDir &&
          (p.equals(existingDir, directory) ||
              p.isWithin(existingDir, directory))) {
        return new Future.value();
      }

      if (p.isWithin(directory, existingDir)) {
        _group.remove(_watchers.remove(existingDir));
        isParentOfExistingDir = true;
      }
    }

    var future = watchDir(directory, poll: _poll);
    var stream = StreamCompleter.fromFuture(future);
    _watchers[directory] = stream;
    _group.add(stream);

    return future;
  }
}
