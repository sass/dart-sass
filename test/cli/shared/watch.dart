// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

import '../../utils.dart';

/// Defines test that are shared between the Dart and Node.js CLI test suites.
void sharedTests(Future<TestProcess> runSass(Iterable<String> arguments)) {
  test("--poll may not be passed without --watch", () async {
    var sass = await runSass(["--poll", "-"]);
    await expectLater(
        sass.stdout, emits("--poll may not be passed without --watch."));
    expect(
        sass.stdout, emitsThrough(contains("Print this usage information.")));
    await sass.shouldExit(64);
  });

  for (var poll in [true, false]) {
    Future<TestProcess> watch(Iterable<String> arguments) => runSass(
        ["--no-source-map", "--watch", ...arguments, if (poll) "--poll"]);

    /// Returns a future that completes after a delay if [poll] is `true`.
    ///
    /// Modifying a file very quickly after it was processed can go
    /// unrecognized, especially on Windows where filesystem operations can have
    /// very high delays.
    Future<void> tickIfPoll() => poll ? tick : Future.value();

    group("${poll ? 'with' : 'without'} --poll", () {
      group("when started", () {
        test("updates a CSS file whose source was modified", () async {
          await d.file("out.css", "x {y: z}").create();
          await tick;
          await d.file("test.scss", "a {b: c}").create();

          var sass = await watch(["test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await sass.kill();

          await d
              .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
              .validate();
        });

        test("doesn't update a CSS file that wasn't modified", () async {
          await d.file("test.scss", "a {b: c}").create();
          await d.file("out.css", "x {y: z}").create();

          var sass = await watch(["test.scss:out.css"]);
          await expectLater(sass.stdout, _watchingForChanges);
          await sass.kill();

          await d.file("out.css", "x {y: z}").validate();
        });

        group("continues compiling after an error", () {
          test("with --error-css", () async {
            await d.file("test1.scss", "a {b: }").create();
            await d.file("test2.scss", "x {y: z}").create();

            var message = 'Error: Expected expression.';
            var sass =
                await watch(["test1.scss:out1.css", "test2.scss:out2.css"]);
            await expectLater(sass.stderr, emits(message));
            await expectLater(
                sass.stderr, emitsThrough(contains('test1.scss 1:7')));
            await expectLater(
                sass.stdout, emitsThrough('Compiled test2.scss to out2.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await sass.kill();

            await d.file("out1.css", contains(message)).validate();
            await d
                .file("out2.css", equalsIgnoringWhitespace("x { y: z; }"))
                .validate();
          });

          test("with --no-error-css", () async {
            await d.file("test1.scss", "a {b: }").create();
            await d.file("test2.scss", "x {y: z}").create();

            var sass = await watch([
              "--no-error-css",
              "test1.scss:out1.css",
              "test2.scss:out2.css"
            ]);
            await expectLater(
                sass.stderr, emits('Error: Expected expression.'));
            await expectLater(
                sass.stderr, emitsThrough(contains('test1.scss 1:7')));
            await expectLater(
                sass.stdout, emitsThrough('Compiled test2.scss to out2.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await sass.kill();

            await d.nothing("out1.css").validate();
            await d
                .file("out2.css", equalsIgnoringWhitespace("x { y: z; }"))
                .validate();
          });
        });

        test("stops compiling after an error with --stop-on-error", () async {
          await d.file("test1.scss", "a {b: }").create();
          await d.file("test2.scss", "x {y: z}").create();

          var sass = await watch([
            "--stop-on-error",
            "test1.scss:out1.css",
            "test2.scss:out2.css"
          ]);

          var message = 'Error: Expected expression.';
          await expectLater(
              sass.stderr,
              emitsInOrder([
                message,
                emitsThrough(contains('test1.scss 1:7')),
                emitsDone
              ]));
          await sass.shouldExit(65);

          await d.file("out1.css", contains(message)).validate();
          await d.nothing("out2.css").validate();
        });
      });

      group("recompiles a watched file", () {
        test("when it's modified", () async {
          await d.file("test.scss", "a {b: c}").create();

          var sass = await watch(["test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          await d.file("test.scss", "x {y: z}").create();
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await sass.kill();

          await d
              .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
              .validate();
        });

        test("when it's modified when watched from a directory", () async {
          await d.dir("dir", [d.file("test.scss", "a {b: c}")]).create();

          var sass = await watch(["dir:out"]);
          await expectLater(
              sass.stdout, emits(_compiled('dir/test.scss', 'out/test.css')));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          await d.dir("dir", [d.file("test.scss", "x {y: z}")]).create();
          await expectLater(
              sass.stdout, emits(_compiled('dir/test.scss', 'out/test.css')));
          await sass.kill();

          await d.dir("out", [
            d.file("test.css", equalsIgnoringWhitespace("x { y: z; }"))
          ]).validate();
        });

        group("when its dependency is modified", () {
          test("through @import", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("test.scss", "@import 'other'").create();

            var sass = await watch(["test.scss:out.css"]);
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            await d.file("_other.scss", "x {y: z}").create();
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await sass.kill();

            await d
                .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                .validate();
          });

          test("through @use", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("test.scss", "@use 'other'").create();

            var sass = await watch(["test.scss:out.css"]);
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            await d.file("_other.scss", "x {y: z}").create();
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await sass.kill();

            await d
                .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                .validate();
          });

          test("through @forward", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("test.scss", "@forward 'other'").create();

            var sass = await watch(["test.scss:out.css"]);
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            await d.file("_other.scss", "x {y: z}").create();
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await sass.kill();

            await d
                .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                .validate();
          });
        });

        test("when it's deleted and re-added", () async {
          await d.file("test.scss", "a {b: c}").create();

          var sass = await watch(["test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          d.file("test.scss").io.deleteSync();
          await expectLater(sass.stdout, emits('Deleted out.css.'));

          // Windows gets confused at the OS level if we don't wait a bit here.
          await tick;

          await d.file("test.scss", "x {y: z}").create();
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await sass.kill();

          await d
              .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
              .validate();
        });

        test("when it gets a parse error", () async {
          await d.file("test.scss", "a {b: c}").create();

          var sass = await watch(["test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          var message = 'Error: Expected expression.';
          await d.file("test.scss", "a {b: }").create();
          await expectLater(sass.stderr, emits(message));
          await expectLater(
              sass.stderr, emitsThrough(contains('test.scss 1:7')));
          await sass.kill();

          await d.file("out.css", contains(message)).validate();
        });

        test("stops compiling after an error with --stop-on-error", () async {
          await d.file("test.scss", "a {b: c}").create();

          var sass = await watch(["--stop-on-error", "test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          var message = 'Error: Expected expression.';
          await d.file("test.scss", "a {b: }").create();
          await expectLater(
              sass.stderr,
              emitsInOrder([
                message,
                emitsThrough(contains('test.scss 1:7')),
                emitsDone
              ]));
          await sass.shouldExit(65);

          await d.file("out.css", contains(message)).validate();
        });

        group("when its dependency is deleted", () {
          test("and updates the output", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("test.scss", "@import 'other'").create();

            var sass = await watch(["test.scss:out.css"]);
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            var message = "Error: Can't find stylesheet to import.";
            d.file("_other.scss").io.deleteSync();
            await expectLater(sass.stderr, emits(message));
            await expectLater(
                sass.stderr, emitsThrough(contains('test.scss 1:9')));
            await sass.kill();

            await d.file("out.css", contains(message)).validate();
          });

          test("but another is available", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("test.scss", "@import 'other'").create();
            await d.dir("dir", [d.file("_other.scss", "x {y: z}")]).create();

            var sass = await watch(["-I", "dir", "test.scss:out.css"]);
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            d.file("_other.scss").io.deleteSync();
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await sass.kill();

            await d
                .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                .validate();
          });

          test("which resolves a conflict", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("_other.sass", "x\n  y: z").create();
            await d.file("test.scss", "@import 'other'").create();

            var sass = await watch(["test.scss:out.css"]);
            await expectLater(sass.stderr,
                emits("Error: It's not clear which file to import. Found:"));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            d.file("_other.sass").io.deleteSync();
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await sass.kill();

            await d
                .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
                .validate();
          });
        });

        group("when a dependency is added", () {
          group("that was missing", () {
            test("relative to the file", () async {
              await d.file("test.scss", "@import 'other'").create();

              var sass = await watch(["test.scss:out.css"]);
              await expectLater(sass.stderr,
                  emits("Error: Can't find stylesheet to import."));
              await expectLater(
                  sass.stderr, emitsThrough(contains("test.scss 1:9")));
              await expectLater(sass.stdout, _watchingForChanges);
              await tickIfPoll();

              await d.file("_other.scss", "a {b: c}").create();
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await sass.kill();

              await d
                  .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
                  .validate();
            });

            test("on a load path", () async {
              await d.file("test.scss", "@import 'other'").create();
              await d.dir("dir").create();

              var sass = await watch(["-I", "dir", "test.scss:out.css"]);
              await expectLater(sass.stderr,
                  emits("Error: Can't find stylesheet to import."));
              await expectLater(
                  sass.stderr, emitsThrough(contains("test.scss 1:9")));
              await expectLater(sass.stdout, _watchingForChanges);
              await tickIfPoll();

              await d.dir("dir", [d.file("_other.scss", "a {b: c}")]).create();
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await sass.kill();

              await d
                  .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
                  .validate();
            });

            test("on a load path that was created", () async {
              await d.dir(
                  "dir1", [d.file("test.scss", "@import 'other'")]).create();

              var sass = await watch(["-I", "dir2", "dir1:out"]);
              await expectLater(sass.stderr,
                  emits("Error: Can't find stylesheet to import."));
              await expectLater(sass.stderr,
                  emitsThrough(contains("${p.join('dir1', 'test.scss')} 1:9")));
              await expectLater(sass.stdout, _watchingForChanges);
              await tickIfPoll();

              await d.dir("dir2", [d.file("_other.scss", "a {b: c}")]).create();
              await expectLater(sass.stdout,
                  emits(_compiled('dir1/test.scss', 'out/test.css')));
              await sass.kill();

              await d
                  .file("out/test.css", equalsIgnoringWhitespace("a { b: c; }"))
                  .validate();
            });
          });

          test("that conflicts with the previous dependency", () async {
            await d.file("_other.scss", "a {b: c}").create();
            await d.file("test.scss", "@import 'other'").create();

            var sass = await watch(["test.scss:out.css"]);
            await expectLater(
                sass.stdout, emits('Compiled test.scss to out.css.'));
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            var message = "Error: It's not clear which file to import. Found:";
            await d.file("_other.sass", "x\n  y: z").create();
            await expectLater(sass.stderr, emits(message));
            await sass.kill();

            await d.file("out.css", contains(message)).validate();
          });

          group("that overrides the previous dependency", () {
            test("on an import path", () async {
              await d.file("test.scss", "@import 'other'").create();
              await d.dir("dir2", [d.file("_other.scss", "a {b: c}")]).create();
              await d.dir("dir1").create();

              var sass = await watch(
                  ["-I", "dir1", "-I", "dir2", "test.scss:out.css"]);
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await expectLater(sass.stdout, _watchingForChanges);
              await tickIfPoll();

              await d.dir("dir1", [d.file("_other.scss", "x {y: z}")]).create();
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await sass.kill();

              await d
                  .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                  .validate();
            });

            test("because it's relative", () async {
              await d.file("test.scss", "@import 'other'").create();
              await d.dir("dir", [d.file("_other.scss", "a {b: c}")]).create();

              var sass = await watch(["-I", "dir", "test.scss:out.css"]);
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await expectLater(sass.stdout, _watchingForChanges);
              await tickIfPoll();

              await d.file("_other.scss", "x {y: z}").create();
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await sass.kill();

              await d
                  .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                  .validate();
            });

            test("because it's not an index", () async {
              await d.file("test.scss", "@import 'other'").create();
              await d
                  .dir("other", [d.file("_index.scss", "a {b: c}")]).create();

              var sass = await watch(["test.scss:out.css"]);
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await expectLater(sass.stdout, _watchingForChanges);
              await tickIfPoll();

              await d.file("_other.scss", "x {y: z}").create();
              await expectLater(
                  sass.stdout, emits('Compiled test.scss to out.css.'));
              await sass.kill();

              await d
                  .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
                  .validate();
            });
          });

          test("gracefully handles a parse error", () async {
            await d.dir("dir").create();

            var sass = await watch(["dir:out"]);
            await expectLater(sass.stdout, _watchingForChanges);
            await tickIfPoll();

            await d.dir("dir", [d.file("test.scss", "a {b: }")]).create();
            await expectLater(
                sass.stderr, emits('Error: Expected expression.'));
            await tickIfPoll();

            await d.dir("dir", [d.file("test.scss", "a {b: c}")]).create();
            await expectLater(
                sass.stdout,
                emits('Compiled ${p.join('dir', 'test.scss')} to '
                    '${p.join('out', 'test.css')}.'));
            await sass.kill();

            await d.dir("out", [
              d.file("test.css", equalsIgnoringWhitespace("a { b: c; }"))
            ]).validate();
          });
        });

        // Regression test for #806
        test("with a .css extension", () async {
          await d.file("test.css", "a {b: c}").create();

          var sass = await watch(["test.css:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.css to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          await d.file("test.css", "x {y: z}").create();
          await expectLater(
              sass.stdout, emits('Compiled test.css to out.css.'));
          await sass.kill();

          await d
              .file("out.css", equalsIgnoringWhitespace("x { y: z; }"))
              .validate();
        });
      });

      group("doesn't recompile the watched file", () {
        test("when an unrelated file is modified", () async {
          await d.dir("dir", [
            d.file("test1.scss", "a {b: c}"),
            d.file("test2.scss", "a {b: c}")
          ]).create();

          var sass = await watch(["dir:out"]);
          await expectLater(
              sass.stdout,
              emitsInAnyOrder([
                _compiled('dir/test1.scss', 'out/test1.css'),
                _compiled('dir/test2.scss', 'out/test2.css')
              ]));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          await d.dir("dir", [d.file("test2.scss", "x {y: z}")]).create();
          await expectLater(
              sass.stdout, emits(_compiled('dir/test2.scss', 'out/test2.css')));
          expect(sass.stdout,
              neverEmits(_compiled('dir/test1.scss', 'out/test1.css')));
          await tick;
          await sass.kill();
        });

        test(
            "when a potential dependency that's not actually imported is added",
            () async {
          await d.file("test.scss", "@import 'other'").create();
          await d.file("_other.scss", "a {b: c}").create();
          await d.dir("dir").create();

          var sass = await watch(["-I", "dir", "test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          await d.dir("dir", [d.file("_other.scss", "a {b: c}")]).create();
          expect(sass.stdout, neverEmits('Compiled test.scss to out.css.'));
          await tick;
          await sass.kill();

          await d
              .file("out.css", equalsIgnoringWhitespace("a { b: c; }"))
              .validate();
        });
      });

      group("deletes the CSS", () {
        test("when a file is deleted", () async {
          await d.file("test.scss", "a {b: c}").create();

          var sass = await watch(["test.scss:out.css"]);
          await expectLater(
              sass.stdout, emits('Compiled test.scss to out.css.'));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          d.file("test.scss").io.deleteSync();
          await expectLater(sass.stdout, emits('Deleted out.css.'));
          await sass.kill();

          await d.nothing("out.css").validate();
        });

        test("when a file is deleted within a directory", () async {
          await d.dir("dir", [d.file("test.scss", "a {b: c}")]).create();

          var sass = await watch(["dir:out"]);
          await expectLater(
              sass.stdout, emits(_compiled('dir/test.scss', 'out/test.css')));
          await expectLater(sass.stdout, _watchingForChanges);
          await tickIfPoll();

          d.file("dir/test.scss").io.deleteSync();
          await expectLater(
              sass.stdout, emits('Deleted ${p.join('out', 'test.css')}.'));
          await sass.kill();

          await d.dir("dir", [d.nothing("out.css")]).validate();
        });
      });

      test("creates a new CSS file when a Sass file is added", () async {
        await d.dir("dir").create();

        var sass = await watch(["dir:out"]);
        await expectLater(sass.stdout, _watchingForChanges);
        await tickIfPoll();

        await d.dir("dir", [d.file("test.scss", "a {b: c}")]).create();
        await expectLater(
            sass.stdout, emits(_compiled('dir/test.scss', 'out/test.css')));
        await sass.kill();

        await d.dir("out", [
          d.file("test.css", equalsIgnoringWhitespace("a { b: c; }"))
        ]).validate();
      });

      test("doesn't create a new CSS file when a partial is added", () async {
        await d.dir("dir").create();

        var sass = await watch(["dir:out"]);
        await expectLater(sass.stdout, _watchingForChanges);
        await tickIfPoll();

        await d.dir("dir", [d.file("_test.scss", "a {b: c}")]).create();
        expect(sass.stdout,
            neverEmits(_compiled('dir/test.scss', 'out/test.css')));
        await tick;
        await sass.kill();

        await d.nothing("out/test.scss").validate();
      });

      // Regression test for #853.
      test("doesn't try to compile a CSS file to itself", () async {
        await d.dir("dir").create();

        var sass = await watch(["dir:dir"]);
        await expectLater(sass.stdout, _watchingForChanges);
        await tickIfPoll();

        await d.file("dir/test.css", "a {b: c}").create();
        await tick;

        // Create a new file that *will* be compiled so that if the first change
        // did incorrectly trigger a compilation, it would emit a message
        // before the message for this change.
        await d.file("dir/test2.scss", "x {y: z}").create();
        await expectLater(
            sass.stdout, emits(_compiled('dir/test2.scss', 'dir/test2.css')));

        await sass.kill();

        await d.file("dir/test.css", "a {b: c}").validate();
      });

      group("doesn't allow", () {
        test("--stdin", () async {
          var sass = await watch(["--stdin", "test.scss"]);
          expect(sass.stdout, emits('--watch is not allowed with --stdin.'));
          await sass.shouldExit(64);
        });

        test("printing to stderr", () async {
          var sass = await watch(["test.scss"]);
          expect(sass.stdout,
              emits('--watch is not allowed when printing to stdout.'));
          await sass.shouldExit(64);
        });
      });
    });
  }
}

/// Returns the message that Sass prints indicating that [from] was compiled to
/// [to], with path separators normalized for the current operating system.
String _compiled(String from, String to) =>
    'Compiled ${p.normalize(from)} to ${p.normalize(to)}.';

/// Matches the output that indicates that Sass is watching for changes.
final _watchingForChanges =
    emitsInOrder(["Sass is watching for changes. Press Ctrl-C to stop.", ""]);
