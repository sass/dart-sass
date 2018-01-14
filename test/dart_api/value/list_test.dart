// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

main() {
  group("a comma-separated list", () {
    Value value;
    setUp(() => value = parseValue("a, b, c"));

    test("is comma-separated", () {
      expect(value.separator, equals(ListSeparator.comma));
    });

    test("has no brackets", () {
      expect(value.hasBrackets, isFalse);
    });

    test("returns its contents as a list", () {
      expect(
          value.asList,
          equals(
              [new SassString("a"), new SassString("b"), new SassString("c")]));
    });

    test("equals the same list", () {
      expect(
          value,
          equalsWithHash(new SassList(
              [new SassString("a"), new SassString("b"), new SassString("c")],
              ListSeparator.comma)));
    });

    test("doesn't equal a value with different metadata", () {
      expect(
          value,
          isNot(equals(new SassList(
              [new SassString("a"), new SassString("b"), new SassString("c")],
              ListSeparator.space))));

      expect(
          value,
          isNot(equals(new SassList([
            new SassString("a"),
            new SassString("b"),
            new SassString("c")
          ], ListSeparator.comma, brackets: true))));
    });

    test("doesn't equal a value with different contents", () {
      expect(
          value,
          isNot(equals(new SassList(
              [new SassString("a"), new SassString("x"), new SassString("c")],
              ListSeparator.comma))));
    });

    group("sassIndexToListIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToListIndex(new SassNumber(1)), equals(0));
        expect(value.sassIndexToListIndex(new SassNumber(2)), equals(1));
        expect(value.sassIndexToListIndex(new SassNumber(3)), equals(2));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToListIndex(new SassNumber(-1)), equals(2));
        expect(value.sassIndexToListIndex(new SassNumber(-2)), equals(1));
        expect(value.sassIndexToListIndex(new SassNumber(-3)), equals(0));
      });

      test("rejects a non-number", () {
        expect(() => value.sassIndexToListIndex(new SassString("foo")),
            throwsSassScriptException);
      });

      test("rejects a non-integer", () {
        expect(() => value.sassIndexToListIndex(new SassNumber(1.1)),
            throwsSassScriptException);
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToListIndex(new SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(new SassNumber(4)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(new SassNumber(-4)),
            throwsSassScriptException);
      });
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  test("a space-separated list is space-separated", () {
    expect(parseValue("a, b, c").separator, equals(ListSeparator.comma));
  });

  test("a bracketed list has brackets", () {
    expect(parseValue("[a, b, c]").hasBrackets, isTrue);
  });

  group("a single-element list", () {
    Value value;
    setUp(() => value = parseValue("[1]"));

    test("has an undecided separator", () {
      expect(value.separator, equals(ListSeparator.undecided));
    });

    test("returns its contents as a list", () {
      expect(value.asList, equals([new SassNumber(1)]));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  test("a comma-separated single-element list is comma-separated", () {
    expect(parseValue("(1,)").separator, equals(ListSeparator.comma));
  });

  group("an empty list", () {
    Value value;
    setUp(() => value = parseValue("()"));

    test("has an undecided separator", () {
      expect(value.separator, equals(ListSeparator.undecided));
    });

    test("returns its contents as a list", () {
      expect(value.asList, isEmpty);
    });

    test("equals an empty map", () {
      expect(value, equalsWithHash(new SassMap.empty()));
    });

    test("counts as an empty map", () {
      expect(value.assertMap().contents, isEmpty);
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });

    test("sassIndexToListIndex() rejects invalid indices", () {
      expect(() => value.sassIndexToListIndex(new SassNumber(0)),
          throwsSassScriptException);
      expect(() => value.sassIndexToListIndex(new SassNumber(1)),
          throwsSassScriptException);
      expect(() => value.sassIndexToListIndex(new SassNumber(-1)),
          throwsSassScriptException);
    });
  });

  group("a scalar value", () {
    Value value;
    setUp(() => value = parseValue("blue"));

    test("has an undecided separator", () {
      expect(value.separator, equals(ListSeparator.undecided));
    });

    test("has no brackets", () {
      expect(value.hasBrackets, isFalse);
    });

    test("returns itself as a list", () {
      var list = value.asList;
      expect(list, hasLength(1));
      expect(list.first, same(value));
    });

    group("sassIndexToListIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToListIndex(new SassNumber(1)), equals(0));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToListIndex(new SassNumber(-1)), equals(0));
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToListIndex(new SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(new SassNumber(2)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(new SassNumber(-2)),
            throwsSassScriptException);
      });
    });
  });

  group("new SassList.empty()", () {
    test("creates an empty list with default metadata", () {
      var list = new SassList.empty();
      expect(list.asList, isEmpty);
      expect(list.separator, equals(ListSeparator.undecided));
      expect(list.hasBrackets, isFalse);
    });

    test("can set the metadata", () {
      var list =
          new SassList.empty(separator: ListSeparator.space, brackets: true);
      expect(list.separator, equals(ListSeparator.space));
      expect(list.hasBrackets, isTrue);
    });
  });

  group("new SassList()", () {
    test("creates a list with the given contents and metadata", () {
      var list = new SassList([new SassString("a")], ListSeparator.space);
      expect(list.asList, equals([new SassString("a")]));
      expect(list.separator, equals(ListSeparator.space));
      expect(list.hasBrackets, isFalse);
    });

    test("can create a bracketed list", () {
      expect(
          new SassList([new SassString("a")], ListSeparator.space,
                  brackets: true)
              .hasBrackets,
          isTrue);
    });

    test("can create a short list with an undecided separator", () {
      expect(
          new SassList([new SassString("a")], ListSeparator.undecided)
              .separator,
          equals(ListSeparator.undecided));
      expect(new SassList([], ListSeparator.undecided).separator,
          equals(ListSeparator.undecided));
    });

    test("can't create a long list with an undecided separator", () {
      expect(
          () => new SassList([new SassString("a"), new SassString("b")],
              ListSeparator.undecided),
          throwsArgumentError);
    });
  });
}
