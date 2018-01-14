// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

main() {
  group("a map with contents", () {
    SassMap value;
    setUp(() => value = parseValue("(a: b, c: d)") as SassMap);

    test("is comma-separated", () {
      expect(value.separator, equals(ListSeparator.comma));
    });

    test("returns its contents as a map", () {
      expect(
          value.contents,
          equals({
            new SassString("a"): new SassString("b"),
            new SassString("c"): new SassString("d")
          }));
    });

    test("returns its contents as a list", () {
      expect(
          value.asList,
          equals([
            new SassList([new SassString("a"), new SassString("b")],
                ListSeparator.space),
            new SassList(
                [new SassString("c"), new SassString("d")], ListSeparator.space)
          ]));
    });

    group("sassIndexToListIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToListIndex(new SassNumber(1)), equals(0));
        expect(value.sassIndexToListIndex(new SassNumber(2)), equals(1));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToListIndex(new SassNumber(-1)), equals(1));
        expect(value.sassIndexToListIndex(new SassNumber(-2)), equals(0));
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToListIndex(new SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(new SassNumber(3)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(new SassNumber(-3)),
            throwsSassScriptException);
      });
    });

    test("equals the same map", () {
      expect(
          value,
          equalsWithHash(new SassMap({
            new SassString("a"): new SassString("b"),
            new SassString("c"): new SassString("d")
          })));
    });

    test("doesn't equal the equivalent list", () {
      expect(
          value,
          isNot(equals(new SassList([
            new SassList([new SassString("a"), new SassString("b")],
                ListSeparator.space),
            new SassList(
                [new SassString("c"), new SassString("d")], ListSeparator.space)
          ], ListSeparator.comma))));
    });

    group("doesn't equal a map with", () {
      test("a different value", () {
        expect(
            value,
            isNot(equals(new SassMap({
              new SassString("a"): new SassString("x"),
              new SassString("c"): new SassString("d")
            }))));
      });

      test("a different key", () {
        expect(
            value,
            isNot(equals(new SassMap({
              new SassString("a"): new SassString("b"),
              new SassString("x"): new SassString("d")
            }))));
      });

      test("a missing pair", () {
        expect(
            value,
            isNot(equals(
                new SassMap({new SassString("a"): new SassString("b")}))));
      });

      test("an additional pair", () {
        expect(
            value,
            isNot(equals(new SassMap({
              new SassString("a"): new SassString("b"),
              new SassString("c"): new SassString("d"),
              new SassString("e"): new SassString("f")
            }))));
      });
    });

    test("is a map", () {
      expect(value.assertMap(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertColor, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("an empty map", () {
    SassMap value;
    setUp(() => value = parseValue("map-remove((a: b), a)") as SassMap);

    test("is comma-separated", () {
      expect(value.separator, equals(ListSeparator.comma));
    });

    test("returns its contents as a map", () {
      expect(value.contents, isEmpty);
    });

    test("returns its contents as a list", () {
      expect(value.asList, isEmpty);
    });

    test("equals an empty list", () {
      expect(value, equalsWithHash(new SassList.empty()));
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

  test("new SassMap.empty() creates an empty map with default metadata", () {
    expect(new SassMap.empty().contents, isEmpty);
  });

  test("new SassMap() creates a map with the given contents", () {
    var list = new SassMap({new SassString("a"): new SassString("b")});
    expect(list.contents, equals({new SassString("a"): new SassString("b")}));
  });
}
