// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

main() {
  test(
      "new Callable() throws a SassFormatException if the argument list is "
      "invalid", () {
    expect(() => new Callable("foo", "arg", (_) => sassNull),
        throwsA(new isInstanceOf<SassFormatException>()));
  });

  test(
      "new AsyncCallable() throws a SassFormatException if the argument list "
      "is invalid", () {
    expect(() => new AsyncCallable("foo", "arg", (_) async => sassNull),
        throwsA(new isInstanceOf<SassFormatException>()));
  });

  test("passes an argument to a custom function and uses its return value", () {
    var css = compileString('a {b: foo(bar)}', functions: [
      new Callable("foo", r"$arg", expectAsync1((arguments) {
        expect(arguments, hasLength(1));
        expect(arguments.first.assertString().text, equals("bar"));
        return new SassString("result");
      }))
    ]);

    expect(css, equalsIgnoringWhitespace("a { b: result; }"));
  });

  test("runs a function asynchronously", () async {
    var css = await compileStringAsync('a {b: foo(bar)}', functions: [
      new AsyncCallable("foo", r"$arg", expectAsync1((arguments) async {
        expect(arguments, hasLength(1));
        expect(arguments.first.assertString().text, equals("bar"));
        await pumpEventQueue();
        return new SassString("result");
      }))
    ]);

    expect(css, equalsIgnoringWhitespace("a { b: result; }"));
  });

  test("passes no arguments to a custom function", () {
    expect(
        compileString('a {b: foo()}', functions: [
          new Callable("foo", "", expectAsync1((arguments) {
            expect(arguments, isEmpty);
            return sassNull;
          }))
        ]),
        isEmpty);
  });

  test("passes multiple arguments to a custom function", () {
    expect(
        compileString('a {b: foo(x, y, z)}', functions: [
          new Callable("foo", r"$arg1, $arg2, $arg3", expectAsync1((arguments) {
            expect(arguments, hasLength(3));
            expect(arguments[0].assertString().text, equals("x"));
            expect(arguments[1].assertString().text, equals("y"));
            expect(arguments[2].assertString().text, equals("z"));
            return sassNull;
          }))
        ]),
        isEmpty);
  });

  test("gracefuly handles a custom function throwing", () {
    expect(() {
      compileString('a {b: foo()}',
          functions: [new Callable("foo", "", (arguments) => throw "heck")]);
    }, throwsA(new isInstanceOf<SassException>()));
  });

  test("gracefuly handles a custom function returning null", () {
    expect(() {
      compileString('a {b: foo()}',
          functions: [new Callable("foo", "", (arguments) => null)]);
    }, throwsA(new isInstanceOf<SassException>()));
  });

  test("supports default argument values", () {
    var css = compileString('a {b: foo()}', functions: [
      new Callable("foo", r"$arg: 1", expectAsync1((arguments) {
        expect(arguments, hasLength(1));
        expect(arguments.first.assertNumber().value, equals(1));
        return arguments.first;
      }))
    ]);

    expect(css, equalsIgnoringWhitespace("a { b: 1; }"));
  });

  test("supports argument lists", () {
    var css = compileString('a {b: foo(1, 2, 3)}', functions: [
      new Callable("foo", r"$args...", expectAsync1((arguments) {
        expect(arguments, hasLength(1));
        var list = arguments[0] as SassArgumentList;
        expect(list.asList, hasLength(3));
        expect(list.asList[0].assertNumber().value, equals(1));
        expect(list.asList[1].assertNumber().value, equals(2));
        expect(list.asList[2].assertNumber().value, equals(3));
        return arguments.first;
      }))
    ]);

    expect(css, equalsIgnoringWhitespace("a { b: 1, 2, 3; }"));
  });

  test("supports keyword arguments", () {
    var css = compileString(r'a {b: foo($bar: 1)}', functions: [
      new Callable("foo", r"$args...", expectAsync1((arguments) {
        expect(arguments, hasLength(1));
        var list = arguments[0] as SassArgumentList;
        expect(list.asList, hasLength(0));
        expect(list.keywords, contains("bar"));
        expect(list.keywords["bar"].assertNumber().value, equals(1));
        return list.keywords["bar"];
      }))
    ]);

    expect(css, equalsIgnoringWhitespace("a { b: 1; }"));
  });
}
