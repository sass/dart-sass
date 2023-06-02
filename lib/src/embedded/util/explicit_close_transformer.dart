// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

/// A [StreamChannelTransformer] that explicitly ensures that when one endpoint
/// closes its sink, the other endpoint will close as well.
///
/// This must be applied to both ends of the channel, and the underlying channel
/// must reserve `null` for a close event.
class ExplicitCloseTransformer<T extends Object>
    implements StreamChannelTransformer<T, T?> {
  const ExplicitCloseTransformer();

  StreamChannel<T> bind(StreamChannel<T?> channel) {
    var closedUnderlyingSink = false;
    return StreamChannel.withCloseGuarantee(channel.stream
        .transform(StreamTransformer.fromHandlers(handleData: (data, sink) {
      if (data == null) {
        channel.sink.close();
        closedUnderlyingSink = true;
      } else {
        sink.add(data);
      }
    })), channel.sink
        .transform(StreamSinkTransformer.fromHandlers(handleDone: (sink) {
      if (!closedUnderlyingSink) {
        sink.add(null);
        sink.close();
      }
    })));
  }
}
