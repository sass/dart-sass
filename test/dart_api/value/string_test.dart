// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  group("an unquoted ASCII string", () {
    SassString value;
    setUp(() => value = parseValue("foobar") as SassString);

    test("has the correct text", () {
      expect(value.text, equals("foobar"));
    });

    test("has no quotes", () {
      expect(value.hasQuotes, isFalse);
    });

    test("equals the same string", () {
      expect(value, equalsWithHash(SassString("foobar", quotes: false)));
      expect(value, equalsWithHash(SassString("foobar", quotes: true)));
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

    test("sassLength returns the length", () {
      expect(value.sassLength, equals(6));
    });

    group("sassIndexToStringIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToStringIndex(SassNumber(1)), equals(0));
        expect(value.sassIndexToStringIndex(SassNumber(2)), equals(1));
        expect(value.sassIndexToStringIndex(SassNumber(3)), equals(2));
        expect(value.sassIndexToStringIndex(SassNumber(4)), equals(3));
        expect(value.sassIndexToStringIndex(SassNumber(5)), equals(4));
        expect(value.sassIndexToStringIndex(SassNumber(6)), equals(5));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToStringIndex(SassNumber(-1)), equals(5));
        expect(value.sassIndexToStringIndex(SassNumber(-2)), equals(4));
        expect(value.sassIndexToStringIndex(SassNumber(-3)), equals(3));
        expect(value.sassIndexToStringIndex(SassNumber(-4)), equals(2));
        expect(value.sassIndexToStringIndex(SassNumber(-5)), equals(1));
        expect(value.sassIndexToStringIndex(SassNumber(-6)), equals(0));
      });

      test("rejects a non-number", () {
        expect(() => value.sassIndexToStringIndex(SassString("foo")),
            throwsSassScriptException);
      });

      test("rejects a non-integer", () {
        expect(() => value.sassIndexToStringIndex(SassNumber(1.1)),
            throwsSassScriptException);
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToStringIndex(SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToStringIndex(SassNumber(7)),
            throwsSassScriptException);
        expect(() => value.sassIndexToStringIndex(SassNumber(-7)),
            throwsSassScriptException);
      });
    });

    group("sassIndexToRuneIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToRuneIndex(SassNumber(1)), equals(0));
        expect(value.sassIndexToRuneIndex(SassNumber(2)), equals(1));
        expect(value.sassIndexToRuneIndex(SassNumber(3)), equals(2));
        expect(value.sassIndexToRuneIndex(SassNumber(4)), equals(3));
        expect(value.sassIndexToRuneIndex(SassNumber(5)), equals(4));
        expect(value.sassIndexToRuneIndex(SassNumber(6)), equals(5));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToRuneIndex(SassNumber(-1)), equals(5));
        expect(value.sassIndexToRuneIndex(SassNumber(-2)), equals(4));
        expect(value.sassIndexToRuneIndex(SassNumber(-3)), equals(3));
        expect(value.sassIndexToRuneIndex(SassNumber(-4)), equals(2));
        expect(value.sassIndexToRuneIndex(SassNumber(-5)), equals(1));
        expect(value.sassIndexToRuneIndex(SassNumber(-6)), equals(0));
      });

      test("rejects a non-number", () {
        expect(() => value.sassIndexToRuneIndex(SassString("foo")),
            throwsSassScriptException);
      });

      test("rejects a non-integer", () {
        expect(() => value.sassIndexToRuneIndex(SassNumber(1.1)),
            throwsSassScriptException);
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToRuneIndex(SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToRuneIndex(SassNumber(7)),
            throwsSassScriptException);
        expect(() => value.sassIndexToRuneIndex(SassNumber(-7)),
            throwsSassScriptException);
      });
    });
  });

  group("a quoted ASCII string", () {
    SassString value;
    setUp(() => value = parseValue('"foobar"') as SassString);

    test("has the correct text", () {
      expect(value.text, equals("foobar"));
    });

    test("has quotes", () {
      expect(value.hasQuotes, isTrue);
    });

    test("equals the same string", () {
      expect(value, equalsWithHash(SassString("foobar", quotes: false)));
      expect(value, equalsWithHash(SassString("foobar", quotes: true)));
    });
  });

  group("an unquoted Unicde", () {
    SassString value;
    setUp(() => value = parseValue("a👭b👬c") as SassString);

    test("sassLength returns the length", () {
      expect(value.sassLength, equals(5));
    });

    group("sassIndexToStringIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToStringIndex(SassNumber(1)), equals(0));
        expect(value.sassIndexToStringIndex(SassNumber(2)), equals(1));
        expect(value.sassIndexToStringIndex(SassNumber(3)), equals(3));
        expect(value.sassIndexToStringIndex(SassNumber(4)), equals(4));
        expect(value.sassIndexToStringIndex(SassNumber(5)), equals(6));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToStringIndex(SassNumber(-1)), equals(6));
        expect(value.sassIndexToStringIndex(SassNumber(-2)), equals(4));
        expect(value.sassIndexToStringIndex(SassNumber(-3)), equals(3));
        expect(value.sassIndexToStringIndex(SassNumber(-4)), equals(1));
        expect(value.sassIndexToStringIndex(SassNumber(-5)), equals(0));
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToStringIndex(SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToStringIndex(SassNumber(6)),
            throwsSassScriptException);
        expect(() => value.sassIndexToStringIndex(SassNumber(-6)),
            throwsSassScriptException);
      });
    });

    group("sassIndexToRuneIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToRuneIndex(SassNumber(1)), equals(0));
        expect(value.sassIndexToRuneIndex(SassNumber(2)), equals(1));
        expect(value.sassIndexToRuneIndex(SassNumber(3)), equals(2));
        expect(value.sassIndexToRuneIndex(SassNumber(4)), equals(3));
        expect(value.sassIndexToRuneIndex(SassNumber(5)), equals(4));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToRuneIndex(SassNumber(-1)), equals(4));
        expect(value.sassIndexToRuneIndex(SassNumber(-2)), equals(3));
        expect(value.sassIndexToRuneIndex(SassNumber(-3)), equals(2));
        expect(value.sassIndexToRuneIndex(SassNumber(-4)), equals(1));
        expect(value.sassIndexToRuneIndex(SassNumber(-5)), equals(0));
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToRuneIndex(SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToRuneIndex(SassNumber(6)),
            throwsSassScriptException);
        expect(() => value.sassIndexToRuneIndex(SassNumber(-6)),
            throwsSassScriptException);
      });
    });
  });

  group("new SassString.empty()", () {
    test("creates an empty unquoted string", () {
      var string = SassString.empty(quotes: false);
      expect(string.text, isEmpty);
      expect(string.hasQuotes, isFalse);
    });

    test("creates an empty quoted string", () {
      var string = SassString.empty(quotes: true);
      expect(string.text, isEmpty);
      expect(string.hasQuotes, isTrue);
    });
  });

  group("new SassString()", () {
    test("creates an unquoted string with the given text", () {
      var string = SassString("a b c", quotes: false);
      expect(string.text, equals("a b c"));
      expect(string.hasQuotes, isFalse);
    });

    test("creates a quoted string with the given text", () {
      var string = SassString("a b c", quotes: true);
      expect(string.text, equals("a b c"));
      expect(string.hasQuotes, isTrue);
    });
  });
}
