// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

main() {
  group("an unquoted string", () {
    SassString value;
    setUp(() => value = parseValue("foobar") as SassString);

    test("has the correct text", () {
      expect(value.text, equals("foobar"));
    });

    test("has no quotes", () {
      expect(value.hasQuotes, isFalse);
    });

    test("equals the same string", () {
      expect(value, equalsWithHash(new SassString("foobar", quotes: false)));
      expect(value, equalsWithHash(new SassString("foobar", quotes: true)));
    });

    test("is a string", () {
      expect(value.assertString(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
    });
  });

  group("a quoted string", () {
    SassString value;
    setUp(() => value = parseValue('"foobar"') as SassString);

    test("has the correct text", () {
      expect(value.text, equals("foobar"));
    });

    test("has quotes", () {
      expect(value.hasQuotes, isTrue);
    });

    test("equals the same string", () {
      expect(value, equalsWithHash(new SassString("foobar", quotes: false)));
      expect(value, equalsWithHash(new SassString("foobar", quotes: true)));
    });
  });

  group("new SassString.empty()", () {
    test("creates an empty unquoted string", () {
      var string = new SassString.empty();
      expect(string.text, isEmpty);
      expect(string.hasQuotes, isFalse);
    });

    test("creates an empty quoted string", () {
      var string = new SassString.empty(quotes: true);
      expect(string.text, isEmpty);
      expect(string.hasQuotes, isTrue);
    });
  });

  group("new SassString()", () {
    test("creates an unquoted string with the given text", () {
      var string = new SassString("a b c");
      expect(string.text, equals("a b c"));
      expect(string.hasQuotes, isFalse);
    });

    test("creates a quoted string with the given text", () {
      var string = new SassString("a b c", quotes: true);
      expect(string.text, equals("a b c"));
      expect(string.hasQuotes, isTrue);
    });
  });
}
