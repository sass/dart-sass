// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  test("rejects invalid options", () async {
    var invalidArgs = [
      '--stdin',
      '--indented',
      '--load-path=x',
      '--style=compressed',
      '--source-map',
      '--source-map-urls=absolute',
      '--embed-sources',
      '--embed-source-map'
    ];
    for (var arg in invalidArgs) {
      var sass = await runSass(["--interactive", arg]);
      expect(sass.stdout,
          emitsThrough(contains("isn't allowed with --interactive")));
      sass.stdin.close();
      await sass.shouldExit(64);
    }
  });

  test("works with no input", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.close();
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  test("works for expressions", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln("4 + 5");
    sass.stdin.close();
    expect(sass.stdout, emitsInOrder([">> 4 + 5", "9"]));
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  test("works for declarations", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln(r"$x: 6");
    sass.stdin.close();
    expect(sass.stdout, emitsInOrder([r">> $x: 6", "6"]));
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  test("works for variable usage", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln(r"$x: 4");
    sass.stdin.writeln(r"$x * 2");
    sass.stdin.close();
    expect(sass.stdout, emitsInOrder([r">> $x: 4", "4", r">> $x * 2", "8"]));
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  test("ignores empty lines", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln("");
    sass.stdin.writeln("  ");
    sass.stdin.close();
    expect(sass.stdout, emitsInOrder([">> ", ">>   "]));
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  test("logs proper errors", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln("1 + 2;");
    sass.stdin.writeln("max(2, 1 + blue)");
    sass.stdin.writeln(r"1 + $x + 3");
    sass.stdin.writeln("foo(");
    sass.stdin.writeln("call('max', 1, 2) + blue");
    sass.stdin.close();
    expect(
        sass.stdout,
        emitsInOrder([
          ">> 1 + 2;",
          "        ^",
          "Error: expected no more input.",
          ">> max(2, 1 + blue)",
          "          ^^^^^^^^",
          'Error: Undefined operation "1 + blue".',
          r">> 1 + $x + 3",
          r"       ^^",
          "Error: Undefined variable.",
          ">> foo(",
          "       ^",
          'Error: expected ")".',
          ">> call('max', 1, 2) + blue",
          'Error: Undefined operation "2 + blue".',
          "call('max', 1, 2) + blue",
          "^^^^^^^^^^^^^^^^^^^^^^^^"
        ]));
    expect(sass.stdout, emitsDone);
    expect(sass.stderr, emitsThrough(contains("DEPRECATION WARNING")));
    await sass.shouldExit(0);
  });

  test("logs proper errors with color", () async {
    var sass = await runSass(["--interactive", "--color"]);
    sass.stdin.writeln("1 + 2;");
    sass.stdin.writeln("max(2, 1 + blue)");
    sass.stdin.writeln(r"1 + $x + 3");
    sass.stdin.writeln("foo(");
    sass.stdin.close();
    expect(
        sass.stdout,
        emitsInOrder([
          ">> 1 + 2;",
          "\u001b[31m\u001b[1F\u001b[8C;",
          "        ^",
          "\u001b[0mError: expected no more input.",
          ">> max(2, 1 + blue)",
          "\u001b[31m\u001b[1F\u001b[10C1 + blue",
          "          ^^^^^^^^",
          '\u001b[0mError: Undefined operation "1 + blue".',
          r">> 1 + $x + 3",
          "\u001b[31m\u001b[1F\u001b[7C\$x",
          r"       ^^",
          "\u001b[0mError: Undefined variable.",
          ">> foo(",
          "\u001b[31m       ^",
          '\u001b[0mError: expected ")".'
        ]));
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });
}
