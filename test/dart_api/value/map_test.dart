// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  group("a map with contents", () {
    SassMap value;
    setUp(() => value = parseValue("(a: b, c: d)") as SassMap);

    test("has an undecided separator", () {
      expect(value.separator, equals(ListSeparator.comma));
    });

    test("returns its contents as a map", () {
      expect(
          value.contents,
          equals({
            SassString("a", quotes: false): SassString("b", quotes: false),
            SassString("c", quotes: false): SassString("d", quotes: false)
          }));
    });

    test("returns its contents as a list", () {
      expect(
          value.asList,
          equals([
            SassList([
              SassString("a", quotes: false),
              SassString("b", quotes: false)
            ], ListSeparator.space),
            SassList([
              SassString("c", quotes: false),
              SassString("d", quotes: false)
            ], ListSeparator.space)
          ]));
    });

    group("sassIndexToListIndex()", () {
      test("converts a positive index to a Dart index", () {
        expect(value.sassIndexToListIndex(SassNumber(1)), equals(0));
        expect(value.sassIndexToListIndex(SassNumber(2)), equals(1));
      });

      test("converts a negative index to a Dart index", () {
        expect(value.sassIndexToListIndex(SassNumber(-1)), equals(1));
        expect(value.sassIndexToListIndex(SassNumber(-2)), equals(0));
      });

      test("rejects invalid indices", () {
        expect(() => value.sassIndexToListIndex(SassNumber(0)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(SassNumber(3)),
            throwsSassScriptException);
        expect(() => value.sassIndexToListIndex(SassNumber(-3)),
            throwsSassScriptException);
      });
    });

    test("equals the same map", () {
      expect(
          value,
          equalsWithHash(SassMap({
            SassString("a", quotes: false): SassString("b", quotes: false),
            SassString("c", quotes: false): SassString("d", quotes: false)
          })));
    });

    test("doesn't equal the equivalent list", () {
      expect(
          value,
          isNot(equals(SassList([
            SassList([
              SassString("a", quotes: false),
              SassString("b", quotes: false)
            ], ListSeparator.space),
            SassList([
              SassString("c", quotes: false),
              SassString("d", quotes: false)
            ], ListSeparator.space)
          ], ListSeparator.comma))));
    });

    group("doesn't equal a map with", () {
      test("a different value", () {
        expect(
            value,
            isNot(equals(SassMap({
              SassString("a", quotes: false): SassString("x", quotes: false),
              SassString("c", quotes: false): SassString("d", quotes: false)
            }))));
      });

      test("a different key", () {
        expect(
            value,
            isNot(equals(SassMap({
              SassString("a", quotes: false): SassString("b", quotes: false),
              SassString("x", quotes: false): SassString("d", quotes: false)
            }))));
      });

      test("a missing pair", () {
        expect(
            value,
            isNot(equals(SassMap({
              SassString("a", quotes: false): SassString("b", quotes: false)
            }))));
      });

      test("an additional pair", () {
        expect(
            value,
            isNot(equals(SassMap({
              SassString("a", quotes: false): SassString("b", quotes: false),
              SassString("c", quotes: false): SassString("d", quotes: false),
              SassString("e", quotes: false): SassString("f", quotes: false)
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

    test("has an undecided separator", () {
      expect(value.separator, equals(ListSeparator.undecided));
    });

    test("returns its contents as a map", () {
      expect(value.contents, isEmpty);
    });

    test("returns its contents as a list", () {
      expect(value.asList, isEmpty);
    });

    test("equals an empty list", () {
      expect(value, equalsWithHash(SassList.empty()));
    });

    test("sassIndexToListIndex() rejects invalid indices", () {
      expect(() => value.sassIndexToListIndex(SassNumber(0)),
          throwsSassScriptException);
      expect(() => value.sassIndexToListIndex(SassNumber(1)),
          throwsSassScriptException);
      expect(() => value.sassIndexToListIndex(SassNumber(-1)),
          throwsSassScriptException);
    });
  });

  test("new SassMap.empty() creates an empty map with default metadata", () {
    expect(SassMap.empty().contents, isEmpty);
  });

  test("new SassMap() creates a map with the given contents", () {
    var list = SassMap(
        {SassString("a", quotes: false): SassString("b", quotes: false)});
    expect(
        list.contents,
        equals(
            {SassString("a", quotes: false): SassString("b", quotes: false)}));
  });
}
