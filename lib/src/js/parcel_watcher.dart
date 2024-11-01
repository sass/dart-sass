// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

@JS()
extension type ParcelWatcherSubscription(JSObject _) implements JSObject {
  external void unsubscribe();
}

@JS()
extension type ParcelWatcherEvent(JSObject _) implements JSObject {
  external String get type;
  external String get path;
}

/// The @parcel/watcher module.
///
/// See [the docs on npm](https://www.npmjs.com/package/@parcel/watcher).
@JS()
extension type ParcelWatcher(JSObject _) implements JSObject {
  @JS('subscribe')
  external JSPromise<ParcelWatcherSubscription> _subscribe(
      String path, JSFunction callback);
  Future<ParcelWatcherSubscription> subscribe(String path,
          void Function(Object? error, List<ParcelWatcherEvent>) callback) =>
      _subscribe(
              path,
              (JSObject? error, JSArray<ParcelWatcherEvent> events) {
                callback(error, events.toDart);
              }.toJS)
          .toDart;

  @JS('getEventsSince')
  external JSPromise<JSArray<ParcelWatcherEvent>> _getEventsSince(
      String path, String snapshotPath);
  Future<List<ParcelWatcherEvent>> getEventsSince(
          String path, String snapshotPath) async =>
      (await _getEventsSince(path, snapshotPath).toDart).toDart;

  @JS('writeSnapshot')
  external JSPromise<JSAny> _writeSnapshot(String path, String snapshotPath);
  Future<void> writeSnapshot(String path, String snapshotPath) =>
      _writeSnapshot(path, snapshotPath).toDart;
}

@JS('parcel_watcher')
external ParcelWatcher? get parcelWatcher;
