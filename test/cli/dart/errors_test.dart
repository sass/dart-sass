// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../dart_test.dart';
import '../shared/errors.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests(runSass);

  test("for package urls", () async {
    await d.file("test.scss", "@use 'package:nope/test';").create();

    var sass = await runSass(["--no-unicode", "test.scss"]);
    expect(
      sass.stderr,
      emitsInOrder([
        "Error: Can't find stylesheet to import.",
        "  ,",
        "1 | @use 'package:nope/test';",
        "  | ^^^^^^^^^^^^^^^^^^^^^^^^",
        "  '",
        "  test.scss 1:1  root stylesheet",
      ]),
    );
    await sass.shouldExit(65);
  });
}
