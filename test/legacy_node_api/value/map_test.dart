// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:test/test.dart';

import '../api.dart';
import '../utils.dart';
import 'utils.dart';

void main() {
  group("from a parameter", () {
    late NodeSassMap map;
    setUp(() {
      map = parseValue<NodeSassMap>("(a: 2, 1: blue, red: b)");
    });

    test("is instanceof Map", () {
      expect(map, isJSInstanceOf(sass.types.Map));
    });

    test("provides access to its length", () {
      expect(map.getLength(), equals(3));
    });

    test("provides access to its keys", () {
      expect(map.getKey(0), isJSInstanceOf(sass.types.String));
      expect(map.getKey(1), isJSInstanceOf(sass.types.Number));
      expect(map.getKey(2), isJSInstanceOf(sass.types.Color));
    });

    test("provides access to its values", () {
      expect(map.getValue(0), isJSInstanceOf(sass.types.Number));
      expect(map.getValue(1), isJSInstanceOf(sass.types.Color));
      expect(map.getValue(2), isJSInstanceOf(sass.types.String));
    });

    test("throws on invalid key indices", () {
      expect(() => map.getKey(-1), throwsA(anything));
      expect(() => map.getKey(4), throwsA(anything));
    });

    test("throws on invalid value indices", () {
      expect(() => map.getValue(-1), throwsA(anything));
      expect(() => map.getValue(4), throwsA(anything));
    });

    test("values can be set without affecting the underlying map", () {
      expect(
          renderSync(RenderOptions(
              data: r"""
                  a {
                    $map: (a: b, c: d, e: f);
                    b: map-get(foo($map), c);
                    c: map-get($map, c);
                  }
                """,
              functions: jsify({
                r"foo($map)": allowInterop(expectAsync1((NodeSassMap map) {
                  map.setValue(1, callConstructor(sass.types.Number, [1]));
                  expect((map.getValue(1) as NodeSassNumber).getValue(),
                      equals(1));
                  return map;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 1; c: d; }"));
    });

    test("keys can be set without affecting the underlying map", () {
      expect(
          renderSync(RenderOptions(
              data: r"""
                  a {
                    $map: (a: b, c: d, e: f);
                    b: map-get(foo($map), 1);
                    c: map-get($map, 1);
                  }
                """,
              functions: jsify({
                r"foo($map)": allowInterop(expectAsync1((NodeSassMap map) {
                  map.setKey(1, callConstructor(sass.types.Number, [1]));
                  expect(
                      (map.getKey(1) as NodeSassNumber).getValue(), equals(1));
                  return map;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: d; }"));
    });

    test("rejects a duplicate key", () {
      expect(() => map.setKey(0, callConstructor(sass.types.Number, [1])),
          throwsA(anything));
    });

    test("allows an identical key", () {
      map.setKey(0, callConstructor(sass.types.String, ["a"]));
      expect((map.getKey(0) as NodeSassString).getValue(), equals("a"));
    });

    test("has a useful .constructor.name", () {
      expect(map.constructor.name, equals("sass.types.Map"));
    });
  });

  group("from a constructor", () {
    test("is a map with the given length", () {
      var map = callConstructor(sass.types.Map, [3]);
      expect(map, isJSInstanceOf(sass.types.Map));
      expect(map.getLength(), equals(3));
    });

    test("is populated with default keys and values", () {
      var map = callConstructor(sass.types.Map, [3]);
      expect(map.getValue(0), equals(sass.types.Null.NULL));
      expect((map.getKey(0) as NodeSassNumber).getValue(), equals(0));
      expect(map.getValue(1), equals(sass.types.Null.NULL));
      expect((map.getKey(1) as NodeSassNumber).getValue(), equals(1));
      expect(map.getValue(2), equals(sass.types.Null.NULL));
      expect((map.getKey(2) as NodeSassNumber).getValue(), equals(2));
    });

    test("can have its keys set", () {
      var map = callConstructor(sass.types.Map, [3]);
      map.setKey(1, sass.types.Boolean.TRUE);
      expect(map.getKey(1), equals(sass.types.Boolean.TRUE));
    });

    test("can have its values set", () {
      var map = callConstructor(sass.types.Map, [3]);
      map.setValue(1, sass.types.Boolean.TRUE);
      expect(map.getValue(1), equals(sass.types.Boolean.TRUE));
    });

    test("has a useful .constructor.name", () {
      expect(callConstructor(sass.types.Map, [3]).constructor.name,
          equals("sass.types.Map"));
    });
  });
}
