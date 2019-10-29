// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';

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
  // The buffer into which the four-byte little-endian length of the next packet
  // will be written.
  var lengthBuffer = Uint8List(4);

  // The index of the next byte to write to [lengthBuffer]. Once this is equal
  // to [lengthBuffer.length], the full length is available.
  var lengthBufferIndex = 0;

  // The length of the next message, in bytes, read from [lengthBuffer] once
  // it's full.
  int nextMessageLength;

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

    // Adds bytes from [chunk] to [destination] at [destinationIndex] without
    // overflowing the bounds of [destination], and increments [i] for each byte
    // written.
    //
    // Returns the number of bytes written.
    int writeFromChunk(Uint8List destination, int destinationIndex) {
      var bytesToWrite =
          math.min(destination.length - destinationIndex, chunk.length - i);
      destination.setRange(
          destinationIndex, destinationIndex + bytesToWrite, chunk, i);
      i += bytesToWrite;
      return bytesToWrite;
    }

    while (i < chunk.length) {
      // We can be in one of two states here:
      //
      // * Both [nextMessageLength] and [buffer] are `null`, in which case we're
      //   waiting until we have four bytes in [lengthBuffer] to know how big of
      //   a buffer to allocate.
      //
      // * Neither [nextMessageLength] nor [buffer] are `null`, in which case
      //   we're waiting for [buffer] to have [nextMessageLength] in it before
      //   we send it to [queue.local.sink] and start waiting for the next
      //   message.
      if (nextMessageLength == null) {
        lengthBufferIndex += writeFromChunk(lengthBuffer, lengthBufferIndex);
        if (lengthBufferIndex < 4) return;

        nextMessageLength =
            ByteData.view(lengthBuffer.buffer).getUint32(0, Endian.little);
        buffer = Uint8List(nextMessageLength);
        bufferIndex = 0;
      }

      bufferIndex += writeFromChunk(buffer, bufferIndex);
      if (bufferIndex < nextMessageLength) return;

      sink.add(Uint8List.view(buffer.buffer, 0, nextMessageLength));
      lengthBufferIndex = 0;
      nextMessageLength = null;
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
  var messageLength = Uint8List(4);
  ByteData.view(messageLength.buffer)
      .setUint32(0, message.length, Endian.little);
  sink.add(messageLength);
  sink.add(message);
});
