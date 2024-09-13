// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';

import 'package:sass/sass.dart';

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

    test("has a named alpha channel", () {
      expect(value.channel("alpha"), equals(1));
    });

    group("channel()", () {
      test("returns RGB channels", () {
        expect(value.channel("red"), equals(0x12));
        expect(value.channel("green"), equals(0x34));
        expect(value.channel("blue"), equals(0x56));
      });

      test("returns alpha", () {
        expect(value.channel("alpha"), equals(1));
      });

      test("throws for a channel not in this space", () {
        expect(() => value.channel("hue"), throwsSassScriptException);
      });
    });

    test("isChannelMissing() throws for a channel not in this space", () {
      expect(() => value.channel("hue"), throwsSassScriptException);
    });

    test("isChannelPowerless() throws for a channel not in this space", () {
      expect(() => value.channel("hue"), throwsSassScriptException);
    });

    test("has a space", () {
      expect(value.space, equals(ColorSpace.rgb));
    });

    test("is a legacy color", () {
      expect(value.isLegacy, isTrue);
    });

    test("equals the same color", () {
      expect(value, equalsWithHash(SassColor.rgb(0x12, 0x34, 0x56)));
    });

    test("equals an equivalent legacy color", () {
      expect(
          value,
          equalsWithHash(
              SassColor.hsl(210, 65.3846153846154, 20.392156862745097)));
    });

    test("does not equal an equivalent non-legacy color", () {
      expect(value, isNot(equals(SassColor.srgb(0x12, 0x34, 0x56))));
    });

    group("isInGamut", () {
      test("returns true if the color is in the RGB gamut", () {
        expect(value.isInGamut, isTrue);
      });

      test("returns false if the color is outside the RGB gamut", () {
        expect(value.changeChannels({"red": 0x100}).isInGamut, isFalse);
      });
    });

    group("toSpace", () {
      test("converts the color to a given space", () {
        expect(
            value.toSpace(ColorSpace.lab),
            equals(SassColor.lab(
                20.675469453386192, -2.276792630515417, -24.59314874484676)));
      });

      test("with legacyMissing: true, makes a powerless channel missing", () {
        expect(
            SassColor.rgb(0, 0, 0)
                .toSpace(ColorSpace.hsl)
                .isChannelMissing("hue"),
            isTrue);
      });

      test("with legacyMissing: false, makes a powerless channel zero", () {
        var result = SassColor.rgb(0, 0, 0)
            .toSpace(ColorSpace.hsl, legacyMissing: false);
        expect(result.isChannelMissing("hue"), isFalse);
        expect(result.channel("hue"), equals(0));
      });

      test(
          "even with legacyMissing: false, preserves missing channels for same "
          "space", () {
        expect(
            SassColor.rgb(0, null, 0)
                .toSpace(ColorSpace.rgb, legacyMissing: false)
                .isChannelMissing("green"),
            isTrue);
      });
    });

    group("toGamut() brings the color into its gamut", () {
      setUp(() => value = parseValue("rgb(300 200 100)") as SassColor);

      test("with clip", () {
        expect(value.toGamut(GamutMapMethod.clip),
            equals(SassColor.rgb(255, 200, 100)));
      });

      test("with localMinde", () {
        // TODO: update
        expect(value.toGamut(GamutMapMethod.localMinde),
            equals(SassColor.rgb(255, 200, 100)));
      });
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

      test("allows in-gamut alpha", () {
        expect(value.changeRgb(alpha: 1).alpha, equals(1));
        expect(value.changeRgb(alpha: 0).alpha, equals(0));
      });

      test("allows out-of-gamut values", () {
        expect(value.changeRgb(red: -1).red, equals(-1));
        expect(value.changeRgb(red: 0x100).red, equals(0x100));
      });

      test("disallows out-of-gamut alpha", () {
        expect(() => value.changeRgb(alpha: -0.1), throwsRangeError);
        expect(() => value.changeRgb(alpha: 1.1), throwsRangeError);
      });
    });

    test("changeHsl() changes HSL values", () {
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
          value.changeHsl(hue: 120, saturation: 42, lightness: 42, alpha: 0.5),
          equals(SassColor.hsl(120, 42, 42, 0.5)));
    });

    test("changeHwb() changes HWB values", () {
      expect(value.changeHwb(hue: 120),
          equals(SassColor.hwb(120, 7.0588235294117645, 66.27450980392157)));
      expect(value.changeHwb(whiteness: 20),
          equals(SassColor.hwb(210, 20, 66.27450980392157)));
      expect(value.changeHwb(blackness: 42),
          equals(SassColor.hwb(210, 7.0588235294117645, 42)));
      expect(
          value.changeHwb(alpha: 0.5),
          equals(
              SassColor.hwb(210, 7.0588235294117645, 66.27450980392157, 0.5)));
      expect(
          value.changeHwb(hue: 120, whiteness: 42, blackness: 42, alpha: 0.5),
          equals(SassColor.hwb(120, 42, 42, 0.5)));
      expect(value.changeHwb(whiteness: 50),
          equals(SassColor.hwb(210, 43.0016863406408, 56.9983136593592)));
    });

    group("changeChannels()", () {
      test("changes RGB values", () {
        expect(value.changeChannels({"red": 0xAA}),
            equals(SassColor.rgb(0xAA, 0x34, 0x56)));
        expect(value.changeChannels({"green": 0xAA}),
            equals(SassColor.rgb(0x12, 0xAA, 0x56)));
        expect(value.changeChannels({"blue": 0xAA}),
            equals(SassColor.rgb(0x12, 0x34, 0xAA)));
        expect(value.changeChannels({"alpha": 0.5}),
            equals(SassColor.rgb(0x12, 0x34, 0x56, 0.5)));
        expect(
            value.changeChannels(
                {"red": 0xAA, "green": 0xAA, "blue": 0xAA, "alpha": 0.5}),
            equals(SassColor.rgb(0xAA, 0xAA, 0xAA, 0.5)));
      });

      test("allows in-gamut alpha", () {
        expect(value.changeChannels({"alpha": 1}).alpha, equals(1));
        expect(value.changeChannels({"alpha": 0}).alpha, equals(0));
      });

      test("allows out-of-gamut values", () {
        expect(value.changeChannels({"red": -1}).red, equals(-1));
        expect(value.changeChannels({"red": 0x100}).red, equals(0x100));
      });

      test("disallows out-of-gamut alpha", () {
        expect(() => value.changeChannels({"alpha": -0.1}), throwsRangeError);
        expect(() => value.changeChannels({"alpha": 1.1}), throwsRangeError);
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
      expect(value.assertCalculation, throwsSassScriptException);
      expect(value.assertFunction, throwsSassScriptException);
      expect(value.assertMap, throwsSassScriptException);
      expect(value.tryMap(), isNull);
      expect(value.assertNumber, throwsSassScriptException);
      expect(value.assertString, throwsSassScriptException);
    });
  });

  group("a color with a missing channel", () {
    late SassColor value;
    setUp(() =>
        value = parseValue("color(display-p3 0.3 0.4 none)") as SassColor);

    test("reports present channels as present", () {
      expect(value.isChannelMissing("red"), isFalse);
      expect(value.isChannelMissing("green"), isFalse);
      expect(value.isChannelMissing("alpha"), isFalse);
    });

    test("reports the missing channel as missing", () {
      expect(value.isChannelMissing("blue"), isTrue);
    });

    test("reports the missing channel's value as 0", () {
      expect(value.channel("blue"), equals(0));
    });

    test("does not report the missing channel as powerless", () {
      expect(value.isChannelPowerless("blue"), isFalse);
    });
  });

  group("a color with a powerless channel", () {
    late SassColor value;
    setUp(() => value = parseValue("hsl(120 0% 50%)") as SassColor);

    test("reports powerful channels as powerful", () {
      expect(value.isChannelPowerless("saturation"), isFalse);
      expect(value.isChannelPowerless("lightness"), isFalse);
      expect(value.isChannelPowerless("alpha"), isFalse);
    });

    test("reports the powerless channel as powerless", () {
      expect(value.isChannelPowerless("hue"), isTrue);
    });

    test("reports the powerless channel's value", () {
      expect(value.channel("hue"), 120);
    });

    test("does not report the powerless channel as missing", () {
      expect(value.isChannelMissing("hue"), isFalse);
    });
  });

  group("an LCH color", () {
    late SassColor value;
    setUp(() => value = parseValue("lch(42% 42% 120)") as SassColor);

    test("throws for legacy channels", () {
      expect(() => value.red, throwsSassScriptException);
      expect(() => value.green, throwsSassScriptException);
      expect(() => value.blue, throwsSassScriptException);
      expect(() => value.hue, throwsSassScriptException);
      expect(() => value.saturation, throwsSassScriptException);
      expect(() => value.lightness, throwsSassScriptException);
      expect(() => value.whiteness, throwsSassScriptException);
      expect(() => value.blackness, throwsSassScriptException);
    });

    test("has an alpha channel", () {
      expect(value.alpha, equals(1));
    });

    group("channel()", () {
      test("returns LCH channels", () {
        expect(value.channel("lightness"), equals(42));
        expect(value.channel("chroma"), equals(63));
        expect(value.channel("hue"), equals(120));
      });

      test("returns alpha", () {
        expect(value.channel("alpha"), equals(1));
      });

      test("throws for a channel not in this space", () {
        expect(() => value.channel("red"), throwsSassScriptException);
      });
    });

    test("is not a legacy color", () {
      expect(value.isLegacy, isFalse);
    });

    test("equals the same color", () {
      expect(value, equalsWithHash(SassColor.lch(42, 63, 120)));
    });

    test("doesn't equal an equivalent color", () {
      expect(
          value,
          isNot(equals(SassColor.xyzD65(0.07461544022446227,
              0.12417002656711021, 0.011301590030256693))));
    });

    test("changeChannels() changes LCH values", () {
      expect(value.changeChannels({"lightness": 30}),
          equals(SassColor.lch(30, 63, 120)));
      expect(value.changeChannels({"chroma": 30}),
          equals(SassColor.lch(42, 30, 120)));
      expect(
          value.changeChannels({"hue": 80}), equals(SassColor.lch(42, 63, 80)));
      expect(value.changeChannels({"alpha": 0.5}),
          equals(SassColor.lch(42, 63, 120, 0.5)));
      expect(
          value.changeChannels(
              {"lightness": 30, "chroma": 30, "hue": 30, "alpha": 0.5}),
          equals(SassColor.lch(30, 30, 30, 0.5)));
    });
  });

  test("an RGBA color has an alpha channel", () {
    var color = parseValue("rgba(10, 20, 30, 0.7)") as SassColor;
    expect(color.alpha, closeTo(0.7, 1e-11));
  });

  group("new SassColor.rgb()", () {
    test("allows out-of-gamut values", () {
      expect(SassColor.rgb(-1, 0, 0, 0).channel("red"), equals(-1));
      expect(SassColor.rgb(0, 100, 0, 0).channel("green"), equals(100));
    });

    test("disallows out-of-gamut alpha values", () {
      expect(() => SassColor.rgb(0, 0, 0, -0.1), throwsRangeError);
      expect(() => SassColor.rgb(0, 0, 0, 1.1), throwsRangeError);
    });
  });
}
