// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn("vm")

import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/util/number.dart';

import 'utils.dart';

void main() {
  group("an RGB color", () {
    SassColor value;
    setUp(() => value = parseValue("#123456") as SassColor);

    test("has RGB channels", () {
      expect(value.red, equals(0x12));
      expect(value.green, equals(0x34));
      expect(value.blue, equals(0x56));
    });

    test("has HSL channels", () {
      expect(value.hue, equals(210));
      expect(value.saturation, equals(65.3846153846154));
      expect(value.lightness, equals(20.392156862745097));
    });

    test("has an alpha channel", () {
      expect(value.alpha, equals(1));
    });

    test("equals the same color", () {
      expect(value, equalsWithHash(SassColor.rgb(0x12, 0x34, 0x56)));
      expect(
          value,
          equalsWithHash(
              SassColor.hsl(210, 65.3846153846154, 20.392156862745097)));
    });

    group("changeRgb()", () {
      test("changes RGB values", () {
        expect(value.changeRgb(red: 0xAA),
            equals(SassColor.rgb(0xAA, 0x34, 0x56)));
        expect(value.changeRgb(green: 0xAA),
            equals(SassColor.rgb(0x12, 0xAA, 0x56)));
        expect(value.changeRgb(blue: 0xAA),
            equals(SassColor.rgb(0x12, 0x34, 0xAA)));
        expect(value.changeRgb(alpha: 0.5),
            equals(SassColor.rgb(0x12, 0x34, 0x56, 0.5)));
        expect(value.changeRgb(red: 0xAA, green: 0xAA, blue: 0xAA, alpha: 0.5),
            equals(SassColor.rgb(0xAA, 0xAA, 0xAA, 0.5)));
      });

      test("allows valid values", () {
        expect(value.changeRgb(red: 0).red, equals(0));
        expect(value.changeRgb(red: 0xFF).red, equals(0xFF));
        expect(value.changeRgb(green: 0).green, equals(0));
        expect(value.changeRgb(green: 0xFF).green, equals(0xFF));
        expect(value.changeRgb(blue: 0).blue, equals(0));
        expect(value.changeRgb(blue: 0xFF).blue, equals(0xFF));
        expect(value.changeRgb(alpha: 0).alpha, equals(0));
        expect(value.changeRgb(alpha: 1).alpha, equals(1));
      });

      test("disallows invalid values", () {
        expect(() => value.changeRgb(red: -1), throwsRangeError);
        expect(() => value.changeRgb(red: 0x100), throwsRangeError);
        expect(() => value.changeRgb(green: -1), throwsRangeError);
        expect(() => value.changeRgb(green: 0x100), throwsRangeError);
        expect(() => value.changeRgb(blue: -1), throwsRangeError);
        expect(() => value.changeRgb(blue: 0x100), throwsRangeError);
        expect(() => value.changeRgb(alpha: -0.1), throwsRangeError);
        expect(() => value.changeRgb(alpha: 1.1), throwsRangeError);
      });
    });

    group("changeHsl()", () {
      test("changes HSL values", () {
        expect(value.changeHsl(hue: 120),
            equals(SassColor.hsl(120, 65.3846153846154, 20.392156862745097)));
        expect(value.changeHsl(saturation: 42),
            equals(SassColor.hsl(210, 42, 20.392156862745097)));
        expect(value.changeHsl(lightness: 42),
            equals(SassColor.hsl(210, 65.3846153846154, 42)));
        expect(
            value.changeHsl(alpha: 0.5),
            equals(
                SassColor.hsl(210, 65.3846153846154, 20.392156862745097, 0.5)));
        expect(
            value.changeHsl(
                hue: 120, saturation: 42, lightness: 42, alpha: 0.5),
            equals(SassColor.hsl(120, 42, 42, 0.5)));
      });

      test("allows valid values", () {
        expect(value.changeHsl(saturation: 0).saturation, equals(0));
        expect(value.changeHsl(saturation: 100).saturation, equals(100));
        expect(value.changeHsl(lightness: 0).lightness, equals(0));
        expect(value.changeHsl(lightness: 100).lightness, equals(100));
        expect(value.changeHsl(alpha: 0).alpha, equals(0));
        expect(value.changeHsl(alpha: 1).alpha, equals(1));
      });

      test("disallows invalid values", () {
        expect(() => value.changeHsl(saturation: -0.1), throwsRangeError);
        expect(() => value.changeHsl(saturation: 100.1), throwsRangeError);
        expect(() => value.changeHsl(lightness: -0.1), throwsRangeError);
        expect(() => value.changeHsl(lightness: 100.1), throwsRangeError);
        expect(() => value.changeHsl(alpha: -0.1), throwsRangeError);
        expect(() => value.changeHsl(alpha: 1.1), throwsRangeError);
      });
    });

    group("changeAlpha()", () {
      test("changes the alpha value", () {
        expect(value.changeAlpha(0.5),
            equals(SassColor.rgb(0x12, 0x34, 0x56, 0.5)));
      });

      test("allows valid alphas", () {
        expect(value.changeAlpha(0).alpha, equals(0));
        expect(value.changeAlpha(1).alpha, equals(1));
      });

      test("rejects invalid alphas", () {
        expect(() => value.changeAlpha(-0.1), throwsRangeError);
        expect(() => value.changeAlpha(1.1), throwsRangeError);
      });
    });

    test("is a color", () {
      expect(value.assertColor(), equals(value));
    });

    test("isn't any other type", () {
      expect(value.assertBoolean, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("an HSL color", () {
    SassColor value;
    setUp(() => value = parseValue("hsl(120, 42%, 42%)") as SassColor);

    test("has RGB channels", () {
      expect(value.red, equals(0x3E));
      expect(value.green, equals(0x98));
      expect(value.blue, equals(0x3E));
    });

    test("has HSL channels", () {
      expect(value.hue, equals(120));
      expect(value.saturation, equals(42));
      expect(value.lightness, equals(42));
    });

    test("has an alpha channel", () {
      expect(value.alpha, equals(1));
    });

    test("equals the same color", () {
      expect(value, equalsWithHash(SassColor.rgb(0x3E, 0x98, 0x3E)));
      expect(value, equalsWithHash(SassColor.hsl(120, 42, 42)));
    });
  });

  test("an RGBA color has an alpha channel", () {
    var color = parseValue("rgba(10, 20, 30, 0.7)") as SassColor;
    expect(color.alpha, closeTo(0.7, epsilon));
  });

  group("new SassColor.rgb()", () {
    test("allows valid values", () {
      expect(SassColor.rgb(0, 0, 0, 0), equals(parseValue("rgba(0, 0, 0, 0)")));
      expect(SassColor.rgb(0xFF, 0xFF, 0xFF, 1), equals(parseValue("#fff")));
    });

    test("disallows invalid values", () {
      expect(() => SassColor.rgb(-1, 0, 0, 0), throwsRangeError);
      expect(() => SassColor.rgb(0, -1, 0, 0), throwsRangeError);
      expect(() => SassColor.rgb(0, 0, -1, 0), throwsRangeError);
      expect(() => SassColor.rgb(0, 0, 0, -0.1), throwsRangeError);
      expect(() => SassColor.rgb(0x100, 0, 0, 0), throwsRangeError);
      expect(() => SassColor.rgb(0, 0x100, 0, 0), throwsRangeError);
      expect(() => SassColor.rgb(0, 0, 0x100, 0), throwsRangeError);
      expect(() => SassColor.rgb(0, 0, 0, 1.1), throwsRangeError);
    });
  });

  group("new SassColor.hsl()", () {
    test("allows valid values", () {
      expect(SassColor.hsl(0, 0, 0, 0), equals(parseValue("hsla(0, 0, 0, 0)")));
      expect(SassColor.hsl(4320, 100, 100, 1),
          equals(parseValue("hsl(4320, 100, 100)")));
    });

    test("disallows invalid values", () {
      expect(() => SassColor.hsl(0, -0.1, 0, 0), throwsRangeError);
      expect(() => SassColor.hsl(0, 0, -0.1, 0), throwsRangeError);
      expect(() => SassColor.hsl(0, 0, 0, -0.1), throwsRangeError);
      expect(() => SassColor.hsl(0, 100.1, 0, 0), throwsRangeError);
      expect(() => SassColor.hsl(0, 0, 100.1, 0), throwsRangeError);
      expect(() => SassColor.hsl(0, 0, 0, 1.1), throwsRangeError);
    });
  });
}
