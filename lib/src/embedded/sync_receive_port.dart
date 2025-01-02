// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';
export 'vm/sync_receive_port.dart'
    if (dart.library.js) 'js/sync_receive_port.dart';

/// A common interface that is implemented by wrapping
/// Dart Mailbox or JS SyncMessagePort.
abstract interface class SyncReceivePort {
  Uint8List receive();
}
