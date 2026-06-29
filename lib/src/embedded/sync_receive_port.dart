// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';
export 'vm/sync_receive_port.dart'
    if (dart.library.js) 'js/sync_receive_port.dart';

/// A port that receives message synchronously across workers.
abstract interface class SyncReceivePort {
  /// Receives a message from the port.
  ///
  /// Throws [StateError] if called after port has been closed.
  Uint8List receive();
}
