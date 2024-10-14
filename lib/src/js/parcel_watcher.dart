// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:node_interop/util.dart';

@JS()
class ParcelWatcherSubscription {
  external void unsubscribe();
}

@JS()
class ParcelWatcherEvent {
  external String get type;
  external String get path;
}

/// The @parcel/watcher module.
///
/// See [the docs on npm](https://www.npmjs.com/package/@parcel/watcher).
@JS('parcel_watcher')
class ParcelWatcher {
  external static Promise subscribe(String path, Function callback);
  static Future<ParcelWatcherSubscription> subscribeFuture(String path,
          void Function(Object? error, List<ParcelWatcherEvent>) callback) =>
      promiseToFuture(
          subscribe(path, allowInterop((Object? error, List<dynamic> events) {
        callback(error, events.cast<ParcelWatcherEvent>());
      })));

  external static Promise getEventsSince(String path, String snapshotPath);
  static Future<List<ParcelWatcherEvent>> getEventsSinceFuture(
      String path, String snapshotPath) async {
    List<dynamic> events =
        await promiseToFuture(getEventsSince(path, snapshotPath));
    return events.cast<ParcelWatcherEvent>();
  }

  external static Promise writeSnapshot(String path, String snapshotPath);
  static Future<void> writeSnapshotFuture(String path, String snapshotPath) =>
      promiseToFuture(writeSnapshot(path, snapshotPath));
}
