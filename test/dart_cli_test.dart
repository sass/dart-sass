// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import 'package:sass/src/util/path.dart';

import 'cli_shared.dart';

void main() {
  sharedTests(_runSass);

  test("--version prints the Sass version", () async {
    var sass = await _runSass(["--version"]);
    expect(sass.stdout, emits(matches(new RegExp(r"^\d+\.\d+\.\d+"))));
    await sass.shouldExit(0);
  });
}

Future<TestProcess> _runSass(Iterable<String> arguments) => TestProcess.start(
    Platform.executable,
    ["--checked", p.absolute("bin/sass.dart")]..addAll(arguments),
    workingDirectory: d.sandbox,
    description: "sass");
