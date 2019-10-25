// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass_embedded/src/embedded_sass.pb.dart';

import 'embedded_process.dart';
import 'utils.dart';

void main() {
  EmbeddedProcess process;
  setUp(() async {
    process = await EmbeddedProcess.start();
  });

  group("gracefully handles a protocol error", () {
    test("caused by an empty message", () async {
      process.inbound.add(InboundMessage());
      await expectParseError(process, "InboundMessage.message is not set.");
      await process.kill();
    });

    test("caused by an invalid message", () async {
      process.stdin.add([1, 0, 0, 0, 0]);
      await expectParseError(
          process, "Protocol message contained an invalid tag (zero).");
      await process.kill();
    });

    test("without shutting down the compiler", () async {
      process.inbound.add(InboundMessage());
      await expectParseError(process, "InboundMessage.message is not set.");

      process.inbound.add(compileString("a {b: c}"));
      await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
      await process.kill();
    });
  });

  test("compiles a CSS from a string", () async {
    process.inbound.add(compileString("a {b: c}"));
    await expectLater(process.outbound, emits(isSuccess("a { b: c; }")));
    await process.kill();
  });
}
