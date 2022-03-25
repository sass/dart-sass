// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/util/number.dart';

import 'utils.dart';

void main() {
  group("an RGB color", () {
    late SassColor value;
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

    test("has HWB channels", () {
      expect(value.hue, equals(210));
      expect(value.whiteness, equals(7.0588235294117645));
      expect(value.blackness, equals(66.27450980392157));
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

    group("changeHwb()", () {
      test("changes HWB values", () {
        expect(value.changeHwb(hue: 120),
            equals(SassColor.hwb(120, 7.0588235294117645, 66.27450980392157)));
        expect(value.changeHwb(whiteness: 20),
            equals(SassColor.hwb(210, 20, 66.27450980392157)));
        expect(value.changeHwb(blackness: 42),
            equals(SassColor.hwb(210, 7.0588235294117645, 42)));
        expect(
            value.changeHwb(alpha: 0.5),
            equals(SassColor.hwb(
                210, 7.0588235294117645, 66.27450980392157, 0.5)));
        expect(
            value.changeHwb(hue: 120, whiteness: 42, blackness: 42, alpha: 0.5),
            equals(SassColor.hwb(120, 42, 42, 0.5)));
        expect(
            value.changeHwb(whiteness: 50), equals(SassColor.hwb(210, 43, 57)));
      });

      test("allows valid values", () {
        expect(value.changeHwb(whiteness: 0).whiteness, equals(0));
        expect(value.changeHwb(whiteness: 100).whiteness, equals(60.0));
        expect(value.changeHwb(blackness: 0).blackness, equals(0));
        expect(value.changeHwb(blackness: 100).blackness,
            equals(93.33333333333333));
        expect(value.changeHwb(alpha: 0).alpha, equals(0));
        expect(value.changeHwb(alpha: 1).alpha, equals(1));
      });

      test("disallows invalid values", () {
        expect(() => value.changeHwb(whiteness: -0.1), throwsRangeError);
        expect(() => value.changeHwb(whiteness: 100.1), throwsRangeError);
        expect(() => value.changeHwb(blackness: -0.1), throwsRangeError);
        expect(() => value.changeHwb(blackness: 100.1), throwsRangeError);
        expect(() => value.changeHwb(alpha: -0.1), throwsRangeError);
        expect(() => value.changeHwb(alpha: 1.1), throwsRangeError);
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
      expect(value.tryMap(), isNull);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("an HSL color", () {
    late SassColor value;
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

    test("has HWB channels", () {
      expect(value.whiteness, equals(24.313725490196077));
      expect(value.blackness, equals(40.3921568627451));
    });

    test("has an alpha channel", () {
      expect(value.alpha, equals(1));
    });

    test("equals the same color", () {
      expect(value, equalsWithHash(SassColor.rgb(0x3E, 0x98, 0x3E)));
      expect(value, equalsWithHash(SassColor.hsl(120, 42, 42)));
      expect(
          value,
          equalsWithHash(
              SassColor.hwb(120, 24.313725490196077, 40.3921568627451)));
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
      expect(
          SassColor.hsl(0, 0, 0, 0), equals(parseValue("hsla(0, 0%, 0%, 0)")));
      expect(SassColor.hsl(4320, 100, 100, 1),
          equals(parseValue("hsl(4320, 100%, 100%)")));
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

  group("new SassColor.hwb()", () {
    late SassColor value;
    setUp(() => value = SassColor.hwb(120, 42, 42));

    test("has RGB channels", () {
      expect(value.red, equals(0x6B));
      expect(value.green, equals(0x94));
      expect(value.blue, equals(0x6B));
    });

    test("has HSL channels", () {
      expect(value.hue, equals(120));
      expect(value.saturation, equals(16.078431372549026));
      expect(value.lightness, equals(50));
    });

    test("has HWB channels", () {
      expect(value.whiteness, equals(41.96078431372549));
      expect(value.blackness, equals(41.96078431372548));
    });

    test("has an alpha channel", () {
      expect(value.alpha, equals(1));
    });

    test("equals the same color", () {
      expect(value, equalsWithHash(SassColor.rgb(0x6B, 0x94, 0x6B)));
      expect(value, equalsWithHash(SassColor.hsl(120, 16, 50)));
      expect(value, equalsWithHash(SassColor.hwb(120, 42, 42)));
    });

    test("allows valid values", () {
      expect(
          SassColor.hwb(0, 0, 0, 0), equals(parseValue("rgba(255, 0, 0, 0)")));
      expect(SassColor.hwb(4320, 100, 100, 1), equals(parseValue("grey")));
    });

    test("disallows invalid values", () {
      expect(() => SassColor.hwb(0, -0.1, 0, 0), throwsRangeError);
      expect(() => SassColor.hwb(0, 0, -0.1, 0), throwsRangeError);
      expect(() => SassColor.hwb(0, 0, 0, -0.1), throwsRangeError);
      expect(() => SassColor.hwb(0, 100.1, 0, 0), throwsRangeError);
      expect(() => SassColor.hwb(0, 0, 100.1, 0), throwsRangeError);
      expect(() => SassColor.hwb(0, 0, 0, 1.1), throwsRangeError);
    });
  });
}
