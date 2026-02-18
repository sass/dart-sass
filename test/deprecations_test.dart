// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';

import 'package:sass/sass.dart';

void main() {
  // Deprecated in all version of Dart Sass
  test("callString is violated by passing a string to call", () {
    _expectDeprecation("a { b: call(random)}", Deprecation.callString);
  });

  group("compileStringRelativeUrl is violated by", () {
    test("a fully relative URL", () {
      _expectDeprecationCallback(
          () => compileStringToResult("a {b: c}",
              url: "foo",
              fatalDeprecations: {Deprecation.compileStringRelativeUrl}),
          Deprecation.compileStringRelativeUrl);
    });

    test("a root-relative URL", () {
      _expectDeprecationCallback(
          () => compileStringToResult("a {b: c}",
              url: "/foo",
              fatalDeprecations: {Deprecation.compileStringRelativeUrl}),
          Deprecation.compileStringRelativeUrl);
    });
  });
}

/// Confirms that [source] will error if [deprecation] is fatal.
void _expectDeprecation(String source, Deprecation deprecation) =>
    _expectDeprecationCallback(
        () => compileStringToResult(source, fatalDeprecations: {deprecation}),
        deprecation);

/// Confirms that [callback] will produce a fatal deprecation error for
/// [deprecation].
void _expectDeprecationCallback(void callback(), Deprecation deprecation) {
  try {
    callback();
  } catch (e) {
    if (e.toString().contains("$deprecation deprecation to be fatal")) return;
    fail('Unexpected error: $e');
  }
  fail("No error for violating $deprecation.");
}
