// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:native_synchronization/mailbox.dart';

import '../sync_receive_port.dart';

final class MailboxSyncReceivePort implements SyncReceivePort {
  final Mailbox _mailbox;

  MailboxSyncReceivePort(this._mailbox);

  Uint8List receive() {
    return _mailbox.take();
  }
}
