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
}
