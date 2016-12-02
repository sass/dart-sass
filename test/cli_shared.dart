// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:scheduled_test/scheduled_process.dart';
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(
    ScheduledProcess startExecutable(List arguments, {workingDirectory})) {
  test("--help prints the usage documentation", () {
    // Checking the entire output is brittle, so just do a sanity check to make
    // sure it's not totally busted.
    var sass = startExecutable(["--help"]);
    sass.stdout.expect("Compile Sass to CSS.");
    sass.stdout
        .expect(consumeThrough(contains("Print this usage information.")));
    sass.shouldExit(64);
  });
}
