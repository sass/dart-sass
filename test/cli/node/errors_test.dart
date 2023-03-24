// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
@Tags(['node'])

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import '../../ensure_npm_package.dart';
import '../node_test.dart';
import '../shared/errors.dart';

void main() {
  setUpAll(ensureNpmPackage);
  sharedTests(runSass);

  test("for package urls", () async {
    await d.file("test.scss", "@import 'package:nope/test';").create();

    var sass = await runSass(["--no-unicode", "test.scss"]);
    expect(
        sass.stderr,
        emitsInOrder([
          "Error: \"package:\" URLs aren't supported on this platform.",
          "  ,",
          "1 | @import 'package:nope/test';",
          "  |         ^^^^^^^^^^^^^^^^^^^",
          "  '",
          "  test.scss 1:9  root stylesheet"
        ]));
    await sass.shouldExit(65);
  });
}
