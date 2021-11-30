// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:test/test.dart';

import 'package:sass/sass.dart';

import '../api.dart';
import '../utils.dart';
import 'utils.dart';

void main() {
  group("from a parameter", () {
    late NodeSassColor color;
    setUp(() {
      color = parseValue<NodeSassColor>("rgba(42, 84, 126, 0.42)");
    });

    test("is instanceof Color", () {
      expect(color, isJSInstanceOf(sass.types.Color));
    });

    test("provides access to its channels", () {
      expect(color.getR(), equals(42));
      expect(color.getG(), equals(84));
      expect(color.getB(), equals(126));
      expect(color.getA(), closeTo(0.42, SassNumber.precision));
    });

    test("each channel can be set without affecting the underlying color", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {$color: #abc; b: foo($color); c: $color}",
              functions: jsify({
                r"foo($color)":
                    allowInterop(expectAsync1((NodeSassColor color) {
                  color.setR(11);
                  expect(color.getR(), equals(11));
                  color.setG(22);
                  expect(color.getG(), equals(22));
                  color.setB(33);
                  expect(color.getB(), equals(33));
                  color.setA(0.5);
                  expect(color.getA(), equals(0.5));
                  return color;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: rgba(11, 22, 33, 0.5); c: #abc; }"));
    });

    test("channels are clamped to the valid range", () {
      color.setR(256);
      expect(color.getR(), equals(255));
      color.setR(-1);
      expect(color.getR(), equals(0));

      color.setG(256);
      expect(color.getG(), equals(255));
      color.setG(-1);
      expect(color.getG(), equals(0));

      color.setB(256);
      expect(color.getB(), equals(255));
      color.setB(-1);
      expect(color.getB(), equals(0));

      color.setA(1.01);
      expect(color.getA(), equals(1.0));
      color.setA(-0.01);
      expect(color.getA(), equals(0.0));
    });

    test("channels are rounded to the nearest int", () {
      color.setR(0.4);
      expect(color.getR(), equals(0));
      color.setR(0.5);
      expect(color.getR(), equals(1));

      color.setG(0.4);
      expect(color.getG(), equals(0));
      color.setG(0.5);
      expect(color.getG(), equals(1));

      color.setB(0.4);
      expect(color.getB(), equals(0));
      color.setB(0.5);
      expect(color.getB(), equals(1));
    });

    test("has a useful .constructor.name", () {
      expect(color.constructor.name, equals("sass.types.Color"));
    });
  });

  group("from a constructor", () {
    group("with individual channels", () {
      test("is a color with the given channels", () {
        var color = callConstructor(sass.types.Color, [11, 12, 13, 0.42]);
        expect(color, isJSInstanceOf(sass.types.Color));
        expect(color.getR(), equals(11));
        expect(color.getG(), equals(12));
        expect(color.getB(), equals(13));
        expect(color.getA(), equals(0.42));
      });

      test("the alpha channel defaults to 1", () {
        var color = callConstructor(sass.types.Color, [11, 12, 13]);
        expect(color.getA(), equals(1.0));
      });
    });

    test("with an ARGB hex value, is a color with the given channels", () {
      var color = callConstructor(sass.types.Color, [0x12345678]);
      expect(color, isJSInstanceOf(sass.types.Color));
      expect(color.getR(), equals(0x34));
      expect(color.getG(), equals(0x56));
      expect(color.getB(), equals(0x78));
      expect(color.getA(), equals(0x12 / 0xff));
    });

    test("has a useful .constructor.name", () {
      expect(callConstructor(sass.types.Color, [11, 12, 13]).constructor.name,
          equals("sass.types.Color"));
    });
  });
}
