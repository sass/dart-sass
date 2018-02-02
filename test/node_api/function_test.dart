// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(const ['node'])

import 'dart:async';
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:test/test.dart';

import '../ensure_npm_package.dart';
import 'api.dart';
import 'utils.dart';

void main() {
  setUpAll(ensureNpmPackage);
  useSandbox();

  group("rejects a signature", () {
    test("with an invalid argument list", () {
      var error = renderSyncError(new RenderOptions(
          data: "", functions: jsify({"foo(": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    test("that's an empty string", () {
      var error = renderSyncError(new RenderOptions(
          data: "", functions: jsify({"": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    test("that's just an argument list", () {
      var error = renderSyncError(new RenderOptions(
          data: "", functions: jsify({r"($var)": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    test("with an invalid identifier", () {
      var error = renderSyncError(new RenderOptions(
          data: "", functions: jsify({"~~~": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });
  });

  group("allows a signature", () {
    test("with no argument list", () {
      expect(
          renderSync(new RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo": allowInterop(expectAsync0(
                    () => callConstructor(sass.types.Number, [12])))
              }))),
          equalsIgnoringWhitespace("a { b: 12; }"));
    });

    test("with an empty argument list", () {
      expect(
          renderSync(new RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo()": allowInterop(expectAsync0(
                    () => callConstructor(sass.types.Number, [12])))
              }))),
          equalsIgnoringWhitespace("a { b: 12; }"));
    });
  });

  group("rejects function calls that", () {
    test("have too few arguments", () {
      var error = renderSyncError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({r"foo($var)": allowInterop(neverCalled)})));
      expect(error.toString(), contains(r'Missing argument $var'));
    });

    test("have too many arguments", () {
      var error = renderSyncError(new RenderOptions(
          data: "a {b: foo(1, 2)}",
          functions: jsify({r"foo($var)": allowInterop(neverCalled)})));
      expect(error.toString(),
          contains('Only 1 argument allowed, but 2 were passed.'));
    });

    test("passes a non-existent named argument", () {
      var error = renderSyncError(new RenderOptions(
          data: r"a {b: foo($val: 1)}",
          functions: jsify({r"foo()": allowInterop(neverCalled)})));
      expect(error.toString(), contains(r'No argument named $val.'));
    });
  });

  group("passes arguments", () {
    test("by position", () {
      expect(
          renderSync(new RenderOptions(
              data: "a {b: last(1px, 2em)}",
              functions: jsify({
                r"last($value1, $value2)":
                    allowInterop(expectAsync2((value1, value2) => value2))
              }))),
          equalsIgnoringWhitespace("a { b: 2em; }"));
    });

    test("by name", () {
      expect(
          renderSync(new RenderOptions(
              data: r"a {b: last($value2: 1px, $value1: 2em)}",
              functions: jsify({
                r"last($value1, $value2)":
                    allowInterop(expectAsync2((value1, value2) => value2))
              }))),
          equalsIgnoringWhitespace("a { b: 1px; }"));
    });

    test("by splat", () {
      expect(
          renderSync(new RenderOptions(
              data: "a {b: last((1px 2em)...)}",
              functions: jsify({
                r"last($value1, $value2)":
                    allowInterop(expectAsync2((value1, value2) => value2))
              }))),
          equalsIgnoringWhitespace("a { b: 2em; }"));
    });

    test("by arglist", () {
      expect(
          renderSync(new RenderOptions(
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
      var error = renderSyncError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({"foo": allowInterop(expectAsync0(() => 10))})));
      expect(error.toString(), contains('must be a Sass value type'));
    });

    test("is null", () {
      var error = renderSyncError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({"foo": allowInterop(expectAsync0(() => null))})));
      expect(error.toString(), contains('must be a Sass value type'));
    });
  });

  test("gracefully handles an error from the function", () {
    var error = renderSyncError(new RenderOptions(
        data: "a {b: foo()}",
        functions: jsify({"foo": allowInterop(() => throw "aw beans")})));
    expect(error.toString(), contains('aw beans'));
  });

  group("render()", () {
    test("runs a synchronous function", () {
      expect(
          render(new RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo":
                    allowInterop((_) => callConstructor(sass.types.Number, [1]))
              }))),
          completion(equalsIgnoringWhitespace("a { b: 1; }")));
    });

    test("runs an asynchronous function", () {
      expect(
          render(new RenderOptions(
              data: "a {b: foo()}",
              functions: jsify({
                "foo": allowInterop((done) {
                  new Future.delayed(Duration.ZERO).then((_) {
                    done(callConstructor(sass.types.Number, [1]));
                  });
                })
              }))),
          completion(equalsIgnoringWhitespace("a { b: 1; }")));
    });

    test("reports a synchronous error", () async {
      var error = await renderError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({"foo": allowInterop((_) => throw "aw beans")})));
      expect(error.toString(), contains('aw beans'));
    });

    test("reports an asynchronous error", () async {
      var error = await renderError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((done) {
              new Future.delayed(Duration.ZERO).then((_) {
                done(new JSError("aw beans"));
              });
            })
          })));
      expect(error.toString(), contains('aw beans'));
    });

    test("reports a null return", () async {
      var error = await renderError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((done) {
              new Future.delayed(Duration.ZERO).then((_) {
                done(null);
              });
            })
          })));
      expect(error.toString(), contains('must be a Sass value type'));
    });

    test("reports a call to done without arguments", () async {
      var error = await renderError(new RenderOptions(
          data: "a {b: foo()}",
          functions: jsify({
            "foo": allowInterop((done) {
              new Future.delayed(Duration.ZERO).then((_) {
                done();
              });
            })
          })));
      expect(error.toString(), contains('must be a Sass value type'));
    });

    test("reports an invalid signature", () async {
      var error = await renderError(new RenderOptions(
          data: "", functions: jsify({"foo(": allowInterop(neverCalled)})));
      expect(error.toString(), contains('Invalid signature'));
    });

    group("with fibers", () {
      setUpAll(() {
        try {
          fiber;
        } catch (_) {
          throw "Can't load fibers package.\n"
              "Run pub run grinder before_test.";
        }
      });

      test("runs a synchronous function", () {
        expect(
            render(new RenderOptions(
                data: "a {b: foo()}",
                functions: jsify({
                  "foo": allowInterop(
                      (_) => callConstructor(sass.types.Number, [1]))
                }),
                fiber: fiber)),
            completion(equalsIgnoringWhitespace("a { b: 1; }")));
      });

      test("runs an asynchronous function", () {
        expect(
            render(new RenderOptions(
                data: "a {b: foo()}",
                functions: jsify({
                  "foo": allowInterop((done) {
                    new Future.delayed(Duration.ZERO).then((_) {
                      done(callConstructor(sass.types.Number, [1]));
                    });
                  })
                }),
                fiber: fiber)),
            completion(equalsIgnoringWhitespace("a { b: 1; }")));
      });

      test("reports a synchronous error", () async {
        var error = await renderError(new RenderOptions(
            data: "a {b: foo()}",
            functions: jsify({"foo": allowInterop((_) => throw "aw beans")}),
            fiber: fiber));
        expect(error.toString(), contains('aw beans'));
      });

      test("reports an asynchronous error", () async {
        var error = await renderError(new RenderOptions(
            data: "a {b: foo()}",
            functions: jsify({
              "foo": allowInterop((done) {
                new Future.delayed(Duration.ZERO).then((_) {
                  done(new JSError("aw beans"));
                });
              })
            }),
            fiber: fiber));
        expect(error.toString(), contains('aw beans'));
      });

      test("reports a null return", () async {
        var error = await renderError(new RenderOptions(
            data: "a {b: foo()}",
            functions: jsify({
              "foo": allowInterop((done) {
                new Future.delayed(Duration.ZERO).then((_) {
                  done(null);
                });
              })
            }),
            fiber: fiber));
        expect(error.toString(), contains('must be a Sass value type'));
      });

      test("reports a call to done without arguments", () async {
        var error = await renderError(new RenderOptions(
            data: "a {b: foo()}",
            functions: jsify({
              "foo": allowInterop((done) {
                new Future.delayed(Duration.ZERO).then((_) {
                  done();
                });
              })
            }),
            fiber: fiber));
        expect(error.toString(), contains('must be a Sass value type'));
      });
    });
  },
      // render() and renderError() use Zone.bindBinaryCallbackGuarded(), which
      // is only available on Dart 2.
      tags: "dart2");

  // Node Sass currently doesn't provide any representation of first-class
  // functions, but they shouldn't crash or be corrupted.
  test("a function is passed through as-is", () {
    expect(
        renderSync(new RenderOptions(
            data: "a {b: call(id(get-function('str-length')), 'foo')}",
            functions: jsify({
              r"id($value)": allowInterop(expectAsync1((value) => value))
            }))),
        equalsIgnoringWhitespace("a { b: 3; }"));
  });
}
