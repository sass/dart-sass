// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  group("rejects invalid options:", () {
    var invalidArgs = [
      '--stdin',
      '--indented',
      '--style=compressed',
      '--source-map',
      '--source-map-urls=absolute',
      '--embed-sources',
      '--embed-source-map',
      '--update',
      '--watch'
    ];
    for (var arg in invalidArgs) {
      test(arg, () async {
        var sass = await runSass(["--interactive", arg]);
        expect(sass.stdout,
            emitsThrough(contains("isn't allowed with --interactive")));
        sass.stdin.close();
        await sass.shouldExit(64);
      });
    }
  });

  test("exits when stdin closes", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.close();
    expect(sass.stdout, emitsDone);
    await sass.shouldExit(0);
  });

  test("prints expression values", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln("4 + 5");
    await expectLater(sass.stdout, emitsInOrder([">> 4 + 5", "9"]));
    await sass.kill();
  });

  test("prints declaration values", () async {
    var sass = await runSass(["--interactive"]);
    sass.stdin.writeln(r"$x: 6");
    await expectLater(sass.stdout, emitsInOrder([r">> $x: 6", "6"]));
    await sass.kill();
  });

  test("works for variable usage", () async {
    var sass = await runSass(["--interactive"]);

    sass.stdin.writeln(r"$x: 4");
    await expectLater(sass.stdout, emitsInOrder([r">> $x: 4", "4"]));

    sass.stdin.writeln(r"$x * 2");
    await expectLater(sass.stdout, emitsInOrder([r">> $x * 2", "8"]));

    await sass.kill();
  });

  test("ignores empty lines", () async {
    var sass = await runSass(["--interactive"]);

    sass.stdin.writeln("");
    await expectLater(sass.stdout, emits(">> "));

    sass.stdin.writeln("  ");
    await expectLater(sass.stdout, emits(">>   "));

    await sass.kill();
  });

  group("with @use", () {
    test("uses variables from the @used module", () async {
      await d.file("other.scss", r"$var: 12;").create();

      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("@use 'other'");
      await expectLater(sass.stdout, emits(">> @use 'other'"));

      sass.stdin.writeln(r"other.$var");
      await expectLater(sass.stdout, emitsInOrder([r">> other.$var", "12"]));

      await sass.kill();
    });

    test("uses functions from the @used module", () async {
      await d.file("other.scss", r"@function foo() {@return 12}").create();

      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("@use 'other'");
      await expectLater(sass.stdout, emits(">> @use 'other'"));

      sass.stdin.writeln(r"other.foo()");
      await expectLater(sass.stdout, emitsInOrder([">> other.foo()", "12"]));

      await sass.kill();
    });

    test("uses a built-in module", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("@use 'sass:math'");
      await expectLater(sass.stdout, emits(">> @use 'sass:math'"));

      sass.stdin.writeln(r"math.abs(-1)");
      await expectLater(sass.stdout, emitsInOrder([">> math.abs(-1)", "1"]));

      await sass.kill();
    });

    test("loads a module from the load path", () async {
      await d.dir("dir", [d.file("other.scss", r"$var: 12;")]).create();

      var sass = await runSass(["--load-path=dir", "--interactive"]);
      sass.stdin.writeln("@use 'other'");
      await expectLater(sass.stdout, emits(">> @use 'other'"));

      sass.stdin.writeln(r"other.$var");
      await expectLater(sass.stdout, emitsInOrder([r">> other.$var", "12"]));

      await sass.kill();
    });

    test("loads a module in the global scope", () async {
      await d.file("other.scss", r"$var: 12;").create();

      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("@use 'other' as *");
      await expectLater(sass.stdout, emits(">> @use 'other' as *"));

      sass.stdin.writeln(r"$var");
      await expectLater(sass.stdout, emitsInOrder([r">> $var", "12"]));

      await sass.kill();
    });

    test("loads a module with configuration", () async {
      await d.file("other.scss", r"""
        $var: 12 !default;
        $derived: $var + 13;
      """).create();

      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln(r"@use 'other' with ($var: 1)");
      await expectLater(sass.stdout, emits(r">> @use 'other' with ($var: 1)"));

      sass.stdin.writeln(r"other.$var");
      await expectLater(sass.stdout, emitsInOrder([r">> other.$var", "1"]));

      sass.stdin.writeln(r"other.$derived");
      await expectLater(
          sass.stdout, emitsInOrder([r">> other.$derived", "14"]));

      await sass.kill();
    });
  });

  group("gracefully handles", () {
    test("a parse error", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("1 + 2;");
      await expectLater(
          sass.stdout,
          emitsInOrder(
              [">> 1 + 2;", "        ^", "Error: expected no more input."]));
      await sass.kill();
    });

    test("a parse error in a variable declaration", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("\$foo: 1 + 2;");
      await expectLater(
          sass.stdout,
          emitsInOrder([
            ">> \$foo: 1 + 2;",
            "              ^",
            "Error: expected no more input."
          ]));
      await sass.kill();
    });

    test("a parse error after the end of the input", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("foo(");
      await expectLater(sass.stdout,
          emitsInOrder([">> foo(", "       ^", 'Error: expected ")".']));
      await sass.kill();
    });

    test("a runtime error", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln("max(2, 1 + blue)");
      await expectLater(
          sass.stdout,
          emitsInOrder([
            ">> max(2, 1 + blue)",
            "          ^^^^^^^^",
            'Error: Undefined operation "1 + blue".'
          ]));
      await sass.kill();
    });

    test("an undefined variable", () async {
      var sass = await runSass(["--interactive"]);
      sass.stdin.writeln(r"1 + $x + 3");
      await expectLater(
          sass.stdout,
          emitsInOrder(
              [r">> 1 + $x + 3", "       ^^", "Error: Undefined variable."]));
      await sass.kill();
    });

    test("an error after a warning", () async {
      var sass = await runSass(["--no-unicode", "--interactive"]);
      sass.stdin.writeln("call('max', 1, 2) + blue");
      await expectLater(sass.stderr, emits(contains("DEPRECATION WARNING")));
      await expectLater(
          sass.stdout,
          emitsInOrder([
            ">> call('max', 1, 2) + blue",
            'Error: Undefined operation "2 + blue".',
            "  ,",
            "1 | call('max', 1, 2) + blue",
            "  | ^^^^^^^^^^^^^^^^^^^^^^^^",
            "  '"
          ]));
      await sass.kill();
    });

    group("with @use", () {
      test("a module load error", () async {
        var sass = await runSass(["--no-unicode", "--interactive"]);
        sass.stdin.writeln('@use "non-existent"');
        await expectLater(
            sass.stdout,
            emitsInOrder([
              '>> @use "non-existent"',
              "   ^^^^^^^^^^^^^^^^^^^",
              "Error: Can't find stylesheet to import."
            ]));
        await sass.kill();
      });

      test("a parse error for @use", () async {
        var sass = await runSass(["--no-unicode", "--interactive"]);
        sass.stdin.writeln('@use "other" as');
        await expectLater(
            sass.stdout,
            emitsInOrder([
              '>> @use "other" as',
              "                  ^",
              "Error: Expected identifier."
            ]));
        await sass.kill();
      });

      test("a parse error in a loaded module", () async {
        await d.file("other.scss", r"$var: 1px +").create();

        var sass = await runSass(["--no-unicode", "--interactive"]);
        sass.stdin.writeln('@use "other"');
        await expectLater(
            sass.stdout,
            emitsInOrder([
              '>> @use "other"',
              "Error: Expected expression.",
              "  ,",
              r"1 | $var: 1px +",
              "  |            ^",
              "  '"
            ]));
        await sass.kill();
      });

      test("a runtime error in a loaded module", () async {
        await d.file("other.scss", r"$var: 1px + 1s;").create();

        var sass = await runSass(["--no-unicode", "--interactive"]);
        sass.stdin.writeln('@use "other"');
        await expectLater(
            sass.stdout,
            emitsInOrder([
              '>> @use "other"',
              "Error: Incompatible units s and px.",
              "  ,",
              r"1 | $var: 1px + 1s;",
              "  |       ^^^^^^^^",
              "  '"
            ]));
        await sass.kill();
      });
    });

    group("and colorizes", () {
      test("an error in the source text", () async {
        var sass = await runSass(["--interactive", "--color"]);
        sass.stdin.writeln("max(2, 1 + blue)");
        await expectLater(
            sass.stdout,
            emitsInOrder([
              ">> max(2, 1 + blue)",
              "\u001b[31m\u001b[1F\u001b[10C1 + blue",
              "          ^^^^^^^^",
              '\u001b[0mError: Undefined operation "1 + blue".'
            ]));
        await sass.kill();
      });

      test("an error after the source text", () async {
        var sass = await runSass(["--interactive", "--color"]);
        sass.stdin.writeln("foo(");
        await expectLater(
            sass.stdout,
            emitsInOrder([
              ">> foo(",
              "\u001b[31m       ^",
              '\u001b[0mError: expected ")".'
            ]));
        await sass.kill();
      });
    });
  });
}
