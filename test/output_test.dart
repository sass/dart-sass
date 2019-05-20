// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// Almost all CSS output tests should go in sass-spec rather than here. This
// just covers tests that explicitly validate out that's considered too
// implementation-specific to verify in sass-spec.

import 'package:test/test.dart';

import 'package:sass/sass.dart';

void main() {
  // Regression test for sass/dart-sass#623. This needs to be tested here
  // because sass-spec normalizes CR LF newlines.
  group("normalizes newlines in a loud comment", () {
    test("in SCSS", () {
      expect(compileString("/* foo\r\n * bar */"), equals("/* foo\n * bar */"));
    });

    test("in Sass", () {
      expect(compileString("/*\r\n  foo\r\n  bar", syntax: Syntax.sass),
          equals("/* foo\n * bar */"));
    });
  });

  // Regression test for sass/dart-sass#688. This needs to be tested here
  // because it varies between Dart and Node.
  group("removes exponential notation", () {
    group("for integers", () {
      test(">= 1e21", () {
        expect(compileString("a {b: 1e21}"),
            equalsIgnoringWhitespace("a { b: 1${'0' * 21}; }"));
      });

      // At time of writing, numbers that are 20 digits or fewer are not printed
      // in exponential notation by either Dart or Node, and we rely on that to
      // determine when to get rid of the exponent. This test ensures that if that
      // ever changes, we know about it.
      test("< 1e21", () {
        expect(compileString("a {b: 1e20}"),
            equalsIgnoringWhitespace("a { b: 1${'0' * 20}; }"));
      });
    });

    group("for floating-point numbers", () {
      test(">= 1e21", () {
        expect(compileString("a {b: 1.01e21}"),
            equalsIgnoringWhitespace("a { b: 101${'0' * 19}; }"));
      });

      // At time of writing, numbers that are 20 digits or fewer are not printed
      // in exponential notation by either Dart or Node, and we rely on that to
      // determine when to get rid of the exponent. This test ensures that if that
      // ever changes, we know about it.
      test("< 1e21", () {
        expect(compileString("a {b: 1.01e20}"),
            equalsIgnoringWhitespace("a { b: 101${'0' * 18}; }"));
      });
    });
  });
}
