// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
@Tags(['node'])

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test_process/test_process.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test/test.dart';

import '../ensure_npm_package.dart';
import 'shared.dart';

void main() {
  setUpAll(ensureNpmPackage);

  sharedTests(runSass);

  test("--version prints the Sass and dart2js versions", () async {
    var sass = await runSass(["--version"]);
    expect(
        sass.stdout,
        emits(matches(
            RegExp(r"^\d+\.\d+\.\d+.* compiled with dart2js \d+\.\d+\.\d+"))));
    await sass.shouldExit(0);
  });
}

Future<TestProcess> runSass(Iterable<String> arguments,
        {Map<String, String> environment}) =>
    TestProcess.start("node", [p.absolute("build/npm/sass.js"), ...arguments],
        workingDirectory: d.sandbox,
        environment: environment,
        description: "sass");
