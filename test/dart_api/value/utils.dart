// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/exception.dart';

/// Parses [source] by way of a function call.
Value parseValue(String source) {
  Value value;
  compileString("a {b: foo(($source))}", functions: [
    Callable("foo", r"$arg", expectAsync1((arguments) {
      expect(arguments, hasLength(1));
      value = arguments.first;
      return sassNull;
    }))
  ]);
  return value;
}

/// A matcher that asserts that a function throws a [SassScriptException].
final throwsSassScriptException =
    throwsA(const TypeMatcher<SassScriptException>());

/// Like [equals], but asserts that the hash codes of the values are the same as
/// well.
Matcher equalsWithHash(Object expected) => predicate((actual) {
      expect(actual, equals(expected));
      expect(actual.hashCode, equals(expected.hashCode),
          reason: "Expected $actual's hash code to equal $expected's.");
      return true;
    });
