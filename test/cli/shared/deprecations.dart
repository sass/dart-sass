// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  // Test complaining about invalid deprecations, combinations, etc

  group("--silence-deprecation", () {
    group("prints a warning", () {
      setUp(() => d.file("test.scss", "").create());

      test("for user-authored", () async {
        var sass =
            await runSass(["--silence-deprecation=user-authored", "test.scss"]);
        expect(sass.stderr, emits(contains("User-authored deprecations")));
        await sass.shouldExit(0);
      });

      test("for an obsolete deprecation", () async {
        // TODO: test this when a deprecation is obsoleted
      });

      test("for an inactive future deprecation", () async {
        var sass = await runSass(["--silence-deprecation=import", "test.scss"]);
        expect(sass.stderr, emits(contains("Future import deprecation")));
        await sass.shouldExit(0);
      }, skip: true);

      test("for an active future deprecation", () async {
        var sass = await runSass([
          "--future-deprecation=import",
          "--silence-deprecation=import",
          "test.scss"
        ]);
        expect(sass.stderr, emits(contains("Conflicting options for future")));
        await sass.shouldExit(0);
      }, skip: true);

      test("in watch mode", () async {
        var sass = await runSass([
          "--watch",
          "--poll",
          "--silence-deprecation=user-authored",
          "test.scss:out.css"
        ]);
        expect(sass.stderr, emits(contains("User-authored deprecations")));

        await expectLater(sass.stdout,
            emitsThrough(endsWith('Compiled test.scss to out.css.')));
        await sass.kill();
      });

      test("in repl mode", () async {
        var sass = await runSass(
            ["--interactive", "--silence-deprecation=user-authored"]);
        await expectLater(
            sass.stderr, emits(contains("User-authored deprecations")));
        await sass.kill();
      });
    });

    group("throws an error for an unknown deprecation", () {
      setUp(() => d.file("test.scss", "").create());

      test("in immediate mode", () async {
        var sass =
            await runSass(["--silence-deprecation=unknown", "test.scss"]);
        expect(sass.stdout, emits(contains('Invalid deprecation "unknown".')));
        await sass.shouldExit(64);
      });

      test("in watch mode", () async {
        var sass = await runSass([
          "--watch",
          "--poll",
          "--silence-deprecation=unknown",
          "test.scss:out.css"
        ]);
        expect(sass.stdout, emits(contains('Invalid deprecation "unknown".')));
        await sass.shouldExit(64);
      });

      test("in repl mode", () async {
        var sass =
            await runSass(["--interactive", "--silence-deprecation=unknown"]);
        expect(sass.stdout, emits(contains('Invalid deprecation "unknown".')));
        await sass.shouldExit(64);
      });
    });

    group("silences", () {
      group("a parse-time deprecation", () {
        setUp(
            () => d.file("test.scss", "@if true {} @elseif false {}").create());

        test("in immediate mode", () async {
          var sass =
              await runSass(["--silence-deprecation=elseif", "test.scss"]);
          expect(sass.stderr, emitsDone);
          await sass.shouldExit(0);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--silence-deprecation=elseif",
            "test.scss:out.css"
          ]);
          expect(sass.stderr, emitsDone);

          await expectLater(sass.stdout,
              emitsThrough(endsWith('Compiled test.scss to out.css.')));
          await sass.kill();
        });

        test("in repl mode", () async {
          var sass = await runSass(
              ["--interactive", "--silence-deprecation=strict-unary"]);
          expect(sass.stderr, emitsDone);
          sass.stdin.writeln("4 -(5)");
          await expectLater(sass.stdout, emitsInOrder([">> 4 -(5)", "-1"]));
          await sass.kill();
        });
      });

      group("an evaluation-time deprecation", () {
        setUp(() => d.file("test.scss", """
          @use 'sass:math';
          a {b: math.random(1px)}
        """).create());

        test("in immediate mode", () async {
          var sass = await runSass(
              ["--silence-deprecation=function-units", "test.scss"]);
          expect(sass.stderr, emitsDone);
          await sass.shouldExit(0);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--silence-deprecation=function-units",
            "test.scss:out.css"
          ]);
          expect(sass.stderr, emitsDone);

          await expectLater(sass.stdout,
              emitsThrough(endsWith('Compiled test.scss to out.css.')));
          await sass.kill();
        });

        test("in repl mode", () async {
          var sass = await runSass(
              ["--interactive", "--silence-deprecation=function-units"]);
          expect(sass.stderr, emitsDone);
          sass.stdin.writeln("@use 'sass:math'");
          await expectLater(sass.stdout, emits(">> @use 'sass:math'"));
          sass.stdin.writeln("math.random(1px)");
          await expectLater(
              sass.stdout, emitsInOrder([">> math.random(1px)", "1"]));
          await sass.kill();
        });
      });
    });
  });

  group("--fatal-deprecation", () {
    group("prints a warning", () {
      setUp(() => d.file("test.scss", "").create());

      test("for an obsolete deprecation", () async {
        // TODO: test this when a deprecation is obsoleted
      });

      test("for an inactive future deprecation", () async {
        var sass = await runSass(["--fatal-deprecation=import", "test.scss"]);
        expect(sass.stderr, emits(contains("Future import deprecation")));
        await sass.shouldExit(0);
      }, skip: true);

      test("for a silent deprecation", () async {
        var sass = await runSass([
          "--fatal-deprecation=elseif",
          "--silence-deprecation=elseif",
          "test.scss"
        ]);
        expect(sass.stderr, emits(contains("Ignoring setting to silence")));
        await sass.shouldExit(0);
      });

      test("in watch mode", () async {
        var sass = await runSass([
          "--watch",
          "--poll",
          "--fatal-deprecation=elseif",
          "--silence-deprecation=elseif",
          "test.scss:out.css"
        ]);
        expect(sass.stderr, emits(contains("Ignoring setting to silence")));

        await expectLater(sass.stdout,
            emitsThrough(endsWith('Compiled test.scss to out.css.')));
        await sass.kill();
      });

      test("in repl mode", () async {
        var sass = await runSass([
          "--interactive",
          "--fatal-deprecation=elseif",
          "--silence-deprecation=elseif"
        ]);
        await expectLater(
            sass.stderr, emits(contains("Ignoring setting to silence")));
        await sass.kill();
      });
    });

    group("throws an error for", () {
      group("an unknown deprecation", () {
        setUp(() => d.file("test.scss", "").create());

        test("in immediate mode", () async {
          var sass =
              await runSass(["--fatal-deprecation=unknown", "test.scss"]);
          expect(
              sass.stdout, emits(contains('Invalid deprecation "unknown".')));
          await sass.shouldExit(64);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--fatal-deprecation=unknown",
            "test.scss:out.css"
          ]);
          expect(
              sass.stdout, emits(contains('Invalid deprecation "unknown".')));
          await sass.shouldExit(64);
        });

        test("in repl mode", () async {
          var sass =
              await runSass(["--interactive", "--fatal-deprecation=unknown"]);
          expect(
              sass.stdout, emits(contains('Invalid deprecation "unknown".')));
          await sass.shouldExit(64);
        });
      });

      group("a parse-time deprecation", () {
        setUp(
            () => d.file("test.scss", "@if true {} @elseif false {}").create());

        test("in immediate mode", () async {
          var sass = await runSass(["--fatal-deprecation=elseif", "test.scss"]);
          expect(sass.stderr, emits(startsWith("Error: ")));
          await sass.shouldExit(65);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--fatal-deprecation=elseif",
            "test.scss:out.css"
          ]);
          await expectLater(sass.stderr, emits(startsWith("Error: ")));
          await expectLater(
              sass.stdout,
              emitsInOrder(
                  ["Sass is watching for changes. Press Ctrl-C to stop.", ""]));
          await sass.kill();
        });

        test("in repl mode", () async {
          var sass = await runSass(
              ["--interactive", "--fatal-deprecation=strict-unary"]);
          sass.stdin.writeln("4 -(5)");
          await expectLater(
              sass.stdout,
              emitsInOrder([
                ">> 4 -(5)",
                emitsThrough(startsWith("Error: ")),
                emitsThrough(contains("Remove this setting"))
              ]));

          // Verify that there's no output written for the previous line.
          sass.stdin.writeln("1");
          await expectLater(sass.stdout, emitsInOrder([">> 1", "1"]));
          await sass.kill();
        });
      });

      group("an evaluation-time deprecation", () {
        setUp(() => d.file("test.scss", """
          @use 'sass:math';
          a {b: math.random(1px)}
        """).create());

        test("in immediate mode", () async {
          var sass = await runSass(
              ["--fatal-deprecation=function-units", "test.scss"]);
          expect(sass.stderr, emits(startsWith("Error: ")));
          await sass.shouldExit(65);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--fatal-deprecation=function-units",
            "test.scss:out.css"
          ]);
          await expectLater(sass.stderr, emits(startsWith("Error: ")));
          await expectLater(
              sass.stdout,
              emitsInOrder(
                  ["Sass is watching for changes. Press Ctrl-C to stop.", ""]));
          await sass.kill();
        });

        test("in repl mode", () async {
          var sass = await runSass(
              ["--interactive", "--fatal-deprecation=function-units"]);
          sass.stdin.writeln("@use 'sass:math'");
          await expectLater(sass.stdout, emits(">> @use 'sass:math'"));
          sass.stdin.writeln("math.random(1px)");
          await expectLater(
              sass.stdout,
              emitsInOrder([
                ">> math.random(1px)",
                emitsThrough(startsWith("Error: ")),
                emitsThrough(contains("Remove this setting"))
              ]));

          // Verify that there's no output written for the previous line.
          sass.stdin.writeln("1");
          await expectLater(sass.stdout, emitsInOrder([">> 1", "1"]));
          await sass.kill();
        });
      });
    });
  });

  group("--future-deprecation", () {
    group("prints a warning for", () {
      group("an active deprecation", () {
        setUp(() => d.file("test.scss", "").create());

        test("in immediate mode", () async {
          var sass = await runSass(
              ["--future-deprecation=function-units", "test.scss"]);
          expect(sass.stderr,
              emits(contains("function-units is not a future deprecation")));
          await sass.shouldExit(0);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--future-deprecation=function-units",
            "test.scss:out.css"
          ]);
          expect(sass.stderr,
              emits(contains("function-units is not a future deprecation")));

          await expectLater(sass.stdout,
              emitsThrough(endsWith('Compiled test.scss to out.css.')));
          await sass.kill();
        });

        test("in repl mode", () async {
          // TODO: test this when there's an expression-level future deprecation
        });
      });

      group("an obsolete deprecation", () {
        // TODO: test this when there are obsolete deprecations
      });

      group("a parse-time deprecation", () {
        setUp(() async {
          await d.file("test.scss", "@import 'other';").create();
          await d.file("_other.scss", "").create();
        });

        test("in immediate mode", () async {
          var sass =
              await runSass(["--future-deprecation=import", "test.scss"]);
          expect(sass.stderr, emits(startsWith("DEPRECATION WARNING")));
          await sass.shouldExit(0);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--future-deprecation=import",
            "test.scss:out.css"
          ]);

          await expectLater(
              sass.stderr, emits(startsWith("DEPRECATION WARNING")));
          await sass.kill();
        });

        test("in repl mode", () async {
          // TODO: test this when there's an expression-level future deprecation
        });
      });

      group("an evaluation-time deprecation", () {
        // TODO: test this when there's an evaluation-time future deprecation
      });
    });

    group("throws an error for", () {
      group("an unknown deprecation", () {
        setUp(() => d.file("test.scss", "").create());

        test("in immediate mode", () async {
          var sass =
              await runSass(["--future-deprecation=unknown", "test.scss"]);
          expect(
              sass.stdout, emits(contains('Invalid deprecation "unknown".')));
          await sass.shouldExit(64);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--future-deprecation=unknown",
            "test.scss:out.css"
          ]);
          expect(
              sass.stdout, emits(contains('Invalid deprecation "unknown".')));
          await sass.shouldExit(64);
        });

        test("in repl mode", () async {
          var sass =
              await runSass(["--interactive", "--future-deprecation=unknown"]);
          expect(
              sass.stdout, emits(contains('Invalid deprecation "unknown".')));
          await sass.shouldExit(64);
        });
      });

      group("a fatal deprecation", () {
        setUp(() async {
          await d.file("test.scss", "@import 'other';").create();
          await d.file("_other.scss", "").create();
        });

        test("in immediate mode", () async {
          var sass = await runSass([
            "--fatal-deprecation=import",
            "--future-deprecation=import",
            "test.scss"
          ]);
          expect(sass.stderr, emits(startsWith("Error: ")));
          await sass.shouldExit(65);
        });

        test("in watch mode", () async {
          var sass = await runSass([
            "--watch",
            "--poll",
            "--fatal-deprecation=import",
            "--future-deprecation=import",
            "test.scss:out.css"
          ]);
          await expectLater(sass.stderr, emits(startsWith("Error: ")));
          await expectLater(
              sass.stdout,
              emitsInOrder(
                  ["Sass is watching for changes. Press Ctrl-C to stop.", ""]));
          await sass.kill();
        });

        test("in repl mode", () async {
          // TODO: test this when there's an expression-level future deprecation
        });
      });
    });
    // Skipping while no future deprecations exist
  }, skip: true);
}
