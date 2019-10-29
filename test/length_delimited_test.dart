// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:typed_data';

import 'package:sass_embedded/src/util/length_delimited_transformer.dart';

import 'package:async/async.dart';
import 'package:test/test.dart';

void main() {
  group("encoder", () {
    Sink<List<int>> sink;
    Stream<List<int>> stream;
    setUp(() {
      var controller = StreamController<List<int>>();
      sink = controller.sink;
      stream = controller.stream.transform(lengthDelimitedEncoder);
    });

    test("encodes an empty message", () {
      sink.add([]);
      sink.close();
      expect(collectBytes(stream), completion(equals([0, 0, 0, 0])));
    });

    test("encodes a message of length 1", () {
      sink.add([123]);
      sink.close();
      expect(collectBytes(stream), completion(equals([1, 0, 0, 0, 123])));
    });

    test("encodes a message of length greater than 256", () {
      sink.add(List.filled(300, 1));
      sink.close();
      expect(collectBytes(stream),
          completion(equals([44, 1, 0, 0, ...List.filled(300, 1)])));
    });

    test("encodes multiple messages", () {
      sink.add([10]);
      sink.add([20, 30]);
      sink.add([40, 50, 60]);
      sink.close();
      expect(
          collectBytes(stream),
          completion(equals(
              [1, 0, 0, 0, 10, 2, 0, 0, 0, 20, 30, 3, 0, 0, 0, 40, 50, 60])));
    });
  });

  group("decoder", () {
    Sink<List<int>> sink;
    StreamQueue<Uint8List> queue;
    setUp(() {
      var controller = StreamController<List<int>>();
      sink = controller.sink;
      queue = StreamQueue(controller.stream.transform(lengthDelimitedDecoder));
    });

    group("decodes an empty message", () {
      test("from a single chunk", () {
        sink.add([0, 0, 0, 0]);
        expect(queue, emits(isEmpty));
      });

      test("from multiple chunks", () {
        sink.add([0, 0]);
        sink.add([0, 0]);
        expect(queue, emits(isEmpty));
      });

      test("from one chunk per byte", () {
        sink..add([0])..add([0])..add([0])..add([0]);
        expect(queue, emits(isEmpty));
      });

      test("from a chunk that contains more data", () {
        sink.add([0, 0, 0, 0, 1, 0, 0, 0, 100]);
        expect(queue, emits(isEmpty));
      });
    });

    group("decodes a longer message", () {
      test("from a single chunk", () {
        sink.add([4, 0, 0, 0, 1, 2, 3, 4]);
        expect(queue, emits([1, 2, 3, 4]));
      });

      test("from multiple chunks", () {
        sink..add([4, 0])..add([0, 0, 1, 2])..add([3, 4]);
        expect(queue, emits([1, 2, 3, 4]));
      });

      test("from one chunk per byte", () {
        for (var byte in [4, 0, 0, 0, 1, 2, 3, 4]) {
          sink.add([byte]);
        }
        expect(queue, emits([1, 2, 3, 4]));
      });

      test("from a chunk that contains more data", () {
        sink.add([4, 0, 0, 0, 1, 2, 3, 4, 1, 0, 0, 0]);
        expect(queue, emits([1, 2, 3, 4]));
      });

      test("of length greater than 256", () {
        sink.add([44, 1, 0, 0, ...List.filled(300, 1)]);
        expect(queue, emits(List.filled(300, 1)));
      });
    });

    group("decodes multiple messages", () {
      test("from single chunk", () {
        sink.add([4, 0, 0, 0, 1, 2, 3, 4, 2, 0, 0, 0, 101, 102]);
        expect(queue, emits([1, 2, 3, 4]));
        expect(queue, emits([101, 102]));
      });

      test("from multiple chunks", () {
        sink..add([4, 0])..add([0, 0, 1, 2, 3, 4, 2, 0])..add([0, 0, 101, 102]);
        expect(queue, emits([1, 2, 3, 4]));
        expect(queue, emits([101, 102]));
      });

      test("from one chunk per byte", () {
        for (var byte in [4, 0, 0, 0, 1, 2, 3, 4, 2, 0, 0, 0, 101, 102]) {
          sink.add([byte]);
        }
        expect(queue, emits([1, 2, 3, 4]));
        expect(queue, emits([101, 102]));
      });
    });
  });
}
