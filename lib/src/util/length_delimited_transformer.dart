// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:typed_data/typed_data.dart';

/// A [StreamChannelTransformer] that converts a channel that sends and receives
/// arbitrarily-chunked binary data to one that sends and receives packets of
/// set length using [lengthDelimitedEncoder] and [lengthDelimitedDecoder].
final StreamChannelTransformer<Uint8List, List<int>> lengthDelimited =
    StreamChannelTransformer<Uint8List, List<int>>(lengthDelimitedDecoder,
        StreamSinkTransformer.fromStreamTransformer(lengthDelimitedEncoder));

/// A transformer that converts an arbitrarily-chunked byte stream where each
/// packet is prefixed with a 32-bit little-endian number indicating its length
/// into a stream of packet contents.
final lengthDelimitedDecoder =
    StreamTransformer<List<int>, Uint8List>.fromBind((stream) {
  // The number of bits we've consumed so far to fill out [nextMessageLength].
  int nextMessageLengthBits = 0;

  // The length of the next message, in bytes.
  //
  // This is built up from a [varint]. Once it's fully consumed, [buffer] is
  // initialized.
  //
  // [varint]: https://developers.google.com/protocol-buffers/docs/encoding#varints
  int nextMessageLength = 0;

  // The buffer into which the packet data itself is written. Initialized once
  // [nextMessageLength] is known.
  Uint8List buffer;

  // The index of the next byte to write to [buffer]. Once this is equal to
  // [buffer.length] (or equivalently [nextMessageLength]), the full packet is
  // available.
  int bufferIndex;

  // It seems a little silly to use a nested [StreamTransformer] here, but we
  // need the outer one to establish a closure context so we can share state
  // across different input chunks, and the inner one takes care of all the
  // boilerplate of creating a new stream based on [stream].
  return stream
      .transform(StreamTransformer.fromHandlers(handleData: (chunk, sink) {
    // The index of the next byte to read from [chunk]. We have to track this
    // because the chunk may contain the length *and* the message, or even
    // multiple messages.
    var i = 0;

    while (i < chunk.length) {
      // We can be in one of two states here:
      //
      // * [buffer] is `null`, in which case we're adding data to
      //   [nextMessageLength] until we reach a byte with its most significant
      //   bit set to 0.
      //
      // * [buffer] is not `null`, in which case we're waiting for [buffer] to
      //   have [nextMessageLength] bytes in it before we send it to
      //   [queue.local.sink] and start waiting for the next message.
      if (buffer == null) {
        var byte = chunk[i];

        // Varints encode data in the 7 lower bits of each byte, which we access
        // by masking with 0x7f = 0b01111111.
        nextMessageLength += (byte & 0x7f) << nextMessageLengthBits;
        nextMessageLengthBits += 7;
        i++;

        // If the byte is higher than 0x7f = 0b01111111, that means its high bit
        // is set which and so there are more bytes to consume before we know
        // the full message length.
        if (byte > 0x7f) continue;

        // Otherwise, [nextMessageLength] is now finalized and we can allocate
        // the data buffer.
        buffer = Uint8List(nextMessageLength);
        bufferIndex = 0;
      }

      // Copy as many bytes as we can from [chunk] to [buffer], making sure not
      // to try to copy more than the buffer can hold (if the chunk has another
      // message after the current one) or more than the chunk has available (if
      // the current message is split across multiple chunks).
      var bytesToWrite =
          math.min(buffer.length - bufferIndex, chunk.length - i);
      buffer.setRange(bufferIndex, bufferIndex + bytesToWrite, chunk, i);
      i += bytesToWrite;
      bufferIndex += bytesToWrite;
      if (bufferIndex < nextMessageLength) return;

      // Once we've filled the buffer, emit it and reset our state.
      sink.add(buffer);
      nextMessageLength = 0;
      nextMessageLengthBits = 0;
      buffer = null;
      bufferIndex = null;
    }
  }));
});

/// A transformer that adds 32-bit little-endian numbers indicating the length
/// of each packet, so that they can safely be sent over a medium that doesn't
/// preserve packet boundaries.
final lengthDelimitedEncoder =
    StreamTransformer<Uint8List, List<int>>.fromHandlers(
        handleData: (message, sink) {
  var length = message.length;
  if (length == 0) {
    sink.add([0]);
    return;
  }

  // Write the length in varint format, 7 bits at a time from least to most
  // significant.
  var lengthBuffer = Uint8Buffer();
  while (length > 0) {
    // The highest-order bit indicates whether more bytes are necessary to fully
    // express the number. The lower 7 bits indicate the number's value.
    lengthBuffer.add((length > 0x7f ? 0x80 : 0) | (length & 0x7f));
    length >>= 7;
  }

  sink.add(Uint8List.view(lengthBuffer.buffer, 0, lengthBuffer.length));
  sink.add(message);
});
