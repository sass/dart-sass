// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:async';
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'package:sass/src/io.dart';
import 'package:sass/src/value/number.dart';

import '../ensure_npm_package.dart';
import '../hybrid.dart';
import 'api.dart';
import 'utils.dart';

void main() {
  setUpAll(ensureNpmPackage);
  useSandbox();

  group("rejects a signature", () {
    test("with an invalid argument list", () {
      var error = renderSyncError(RenderOptions(
          data: "", functions: jsify({"foo(": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    test("that's an empty string", () {
      var error = renderSyncError(RenderOptions(
          data: "", functions: jsify({"": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    test("that's just an argument list", () {
      var error = renderSyncError(RenderOptions(
          data: "", functions: jsify({r"($var)": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    test("with an invalid identifier", () {
      var error = renderSyncError(RenderOptions(
          data: "", functions: jsify({"~~~": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });
  });

  group("allows a signature", () {
    test("with no argument list", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo": allowInterop(expectAsync0(
                    () => callConstructor(sass.types.Number, [12])))
              }))),
          equalsIgnoringWhitespace("a { b: 12; }"));
    });

    test("with an empty argument list", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo()": allowInterop(expectAsync0(
                    () => callConstructor(sass.types.Number, [12])))
              }))),
          equalsIgnoringWhitespace("a { b: 12; }"));
    });
  });

  group("are dash-normalized", () {
    test("when defined with dashes", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: foo_bar()}",
              functions: jsify({
                "foo-bar": allowInterop(expectAsync0(
                    () => callConstructor(sass.types.Number, [12])))
              }))),
          equalsIgnoringWhitespace("a { b: 12; }"));
    });

    test("when defined with underscores", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: foo-bar()}",
              functions: jsify({
                "foo_bar": allowInterop(expectAsync0(
                    () => callConstructor(sass.types.Number, [12])))
              }))),
          equalsIgnoringWhitespace("a { b: 12; }"));
    });
  });

  group("rejects function calls that", () {
    test("have too few arguments", () {
      var error = renderSyncError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({r"foo($var)": allowInterop(neverCalled)})));
      expect(error.toString(), contains(r'Missing argument $var'));
    });

    test("have too many arguments", () {
      var error = renderSyncError(RenderOptions(
          data: "a {b: foo(1, 2)}",
          functions: jsify({r"foo($var)": allowInterop(neverCalled)})));
      expect(error.toString(),
          contains('Only 1 argument allowed, but 2 were passed.'));
    });

    test("passes a non-existent named argument", () {
      var error = renderSyncError(RenderOptions(
          data: r"a {b: foo($val: 1)}",
          functions: jsify({r"foo()": allowInterop(neverCalled)})));
      expect(error.toString(), contains(r'No argument named $val.'));
    });
  });

  group("passes arguments", () {
    test("by position", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: last(1px, 2em)}",
              functions: jsify({
                r"last($value1, $value2)":
                    allowInterop(expectAsync2((value1, value2) => value2))
              }))),
          equalsIgnoringWhitespace("a { b: 2em; }"));
    });

    test("by name", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: last($value2: 1px, $value1: 2em)}",
              functions: jsify({
                r"last($value1, $value2)":
                    allowInterop(expectAsync2((value1, value2) => value2))
              }))),
          equalsIgnoringWhitespace("a { b: 1px; }"));
    });

    test("by splat", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: last((1px 2em)...)}",
              functions: jsify({
                r"last($value1, $value2)":
                    allowInterop(expectAsync2((value1, value2) => value2))
              }))),
          equalsIgnoringWhitespace("a { b: 2em; }"));
    });

    test("by arglist", () {
      expect(
          renderSync(RenderOptions(
              data: "a {b: last(1px, 2em)}",
              functions: jsify({
                r"last($args...)": allowInterop(expectAsync1(
                    (NodeSassList args) => args.getValue(args.getLength() - 1)))
              }))),
          equalsIgnoringWhitespace("a { b: 2em; }"));
    });
  });

  group("rejects a return value that", () {
    test("isn't a Sass value", () {
      var error = renderSyncError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({"foo": allowInterop(expectAsync0(() => 10))})));
      expect(error.toString(), contains('must be a Sass value type'));
    });

    test("is null", () {
      var error = renderSyncError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({"foo": allowInterop(expectAsync0(() => null))})));
      expect(error.toString(), contains('must be a Sass value type'));
    });
  });

  group('this', () {
    late String sassPath;
    setUp(() async {
      sassPath = p.join(sandbox, 'test.scss');
    });

    test('includes default option values', () {
      renderSync(RenderOptions(
        data: 'a {b: foo()}',
        functions: jsify({
          'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
            var options = this_.options;
            expect(options.includePaths, equals(p.current));
            expect(options.precision, equals(SassNumber.precision));
            expect(options.style, equals(1));
            expect(options.indentType, equals(0));
            expect(options.indentWidth, equals(2));
            expect(options.linefeed, equals('\n'));
            return callConstructor(sass.types.Number, [12]);
          }))
        }),
      ));
    });

    test('includes the data when rendering via data', () {
      renderSync(RenderOptions(
        data: 'a {b: foo()}',
        functions: jsify({
          'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
            expect(this_.options.data, equals('a {b: foo()}'));
            expect(this_.options.file, isNull);
            return callConstructor(sass.types.Number, [12]);
          }))
        }),
      ));
    });

    test('includes the filename when rendering via file', () async {
      await writeTextFile(sassPath, 'a {b: foo()}');
      renderSync(RenderOptions(
        file: sassPath,
        functions: jsify({
          'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
            expect(this_.options.data, isNull);
            expect(this_.options.file, equals(sassPath));
            return callConstructor(sass.types.Number, [12]);
          }))
        }),
      ));
    });

    test('includes other include paths', () {
      renderSync(RenderOptions(
        data: 'a {b: foo()}',
        includePaths: [sandbox],
        functions: jsify({
          'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
            expect(this_.options.includePaths,
                equals('${p.current}${isWindows ? ';' : ':'}$sandbox'));
            return callConstructor(sass.types.Number, [12]);
          }))
        }),
      ));
    });

    group('can override', () {
      test('indentWidth', () {
        renderSync(RenderOptions(
          data: 'a {b: foo()}',
          indentWidth: 5,
          functions: jsify({
            'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
              expect(this_.options.indentWidth, equals(5));
              return callConstructor(sass.types.Number, [12]);
            }))
          }),
        ));
      });

      test('indentType', () {
        renderSync(RenderOptions(
          data: 'a {b: foo()}',
          indentType: 'tab',
          functions: jsify({
            'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
              expect(this_.options.indentType, equals(1));
              return callConstructor(sass.types.Number, [12]);
            }))
          }),
        ));
      });

      test('linefeed', () {
        renderSync(RenderOptions(
          data: 'a {b: foo()}',
          linefeed: 'cr',
          functions: jsify({
            'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
              expect(this_.options.linefeed, equals('\r'));
              return callConstructor(sass.types.Number, [12]);
            }))
          }),
        ));
      });
    });

    test('has a circular reference', () {
      renderSync(RenderOptions(
        data: 'a {b: foo()}',
        functions: jsify({
          'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
            expect(this_.options.context, same(this_));
            return callConstructor(sass.types.Number, [12]);
          }))
        }),
      ));
    });

    group('includes render stats with', () {
      test('a start time', () {
        var start = DateTime.now();
        renderSync(RenderOptions(
          data: 'a {b: foo()}',
          functions: jsify({
            'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
              expect(this_.options.result.stats.start,
                  greaterThanOrEqualTo(start.millisecondsSinceEpoch));
              return callConstructor(sass.types.Number, [12]);
            }))
          }),
        ));
      });

      test('a data entry', () {
        renderSync(RenderOptions(
          data: 'a {b: foo()}',
          functions: jsify({
            'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
              expect(this_.options.result.stats.entry, equals('data'));
              return callConstructor(sass.types.Number, [12]);
            }))
          }),
        ));
      });

      test('a file entry', () async {
        await writeTextFile(sassPath, 'a {b: foo()}');
        renderSync(RenderOptions(
          file: sassPath,
          functions: jsify({
            'foo': allowInteropCaptureThis(expectAsync1((RenderContext this_) {
              expect(this_.options.result.stats.entry, equals(sassPath));
              return callConstructor(sass.types.Number, [12]);
            }))
          }),
        ));
      });
    });
  });

  test("gracefully handles an error from the function", () {
    var error = renderSyncError(RenderOptions(
        data: "a {b: foo()}",
        functions: jsify({"foo": allowInterop(() => throw "aw beans")})));
    expect(error.toString(), contains('aw beans'));
  });

  group("render()", () {
    test("runs a synchronous function", () {
      expect(
          render(RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo": allowInterop(
                    (void _) => callConstructor(sass.types.Number, [1]))
              }))),
          completion(equalsIgnoringWhitespace("a { b: 1; }")));
    });

    test("runs an asynchronous function", () {
      expect(
          render(RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo": allowInterop((void done(Object? result)) {
                  Timer(Duration.zero, () {
                    done(callConstructor(sass.types.Number, [1]));
                  });
                })
              }))),
          completion(equalsIgnoringWhitespace("a { b: 1; }")));
    });

    test("reports a synchronous error", () async {
      var error = await renderError(RenderOptions(
          data: "a {b: foo()}",
          functions:
              jsify({"foo": allowInterop((void _) => throw "aw beans")})));
      expect(error.toString(), contains('aw beans'));
    });

    test("reports a synchronous sass.types.Error", () async {
      var error = await renderError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop(
                (void _) => callConstructor(sass.types.Error, ["aw beans"]))
          })));
      expect(error.toString(), contains('aw beans'));
    });

    test("reports an asynchronous error", () async {
      var error = await renderError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((void done(Object result)) {
              Timer(Duration.zero, () {
                done(JsError("aw beans"));
              });
            })
          })));
      expect(error.toString(), contains('aw beans'));
    });

    test("reports an asynchronous sass.types.Error", () async {
      var error = await renderError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((void done(Object? result)) {
              Timer(Duration.zero, () {
                done(callConstructor(sass.types.Error, ["aw beans"]));
              });
            })
          })));
      expect(error.toString(), contains('aw beans'));
    });

    test("reports a null return", () async {
      var error = await renderError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((void done(Object? result)) {
              Timer(Duration.zero, () {
                done(null);
              });
            })
          })));
      expect(error.toString(), contains('must be a Sass value type'));
    });

    test("reports a call to done without arguments", () async {
      var error = await renderError(RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((void done()) {
              Timer(Duration.zero, () {
                done();
              });
            })
          })));
      expect(error.toString(), contains('must be a Sass value type'));
    });

    test("reports an invalid signature", () async {
      var error = await renderError(RenderOptions(
          data: "", functions: jsify({"foo(": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });
  });

  // Node Sass currently doesn't provide any representation of first-class
  // functions, but they shouldn't crash or be corrupted.
  test("a function is passed through as-is", () {
    expect(
        renderSync(RenderOptions(
            data: "a {b: call(id(get-function('str-length')), 'foo')}",
            functions: jsify({
              r"id($value)": allowInterop(expectAsync1((value) => value))
            }))),
        equalsIgnoringWhitespace("a { b: 3; }"));
  });
}
