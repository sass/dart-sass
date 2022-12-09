// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found at https://opensource.org/licenses/MIT.

import 'dart:typed_data';

import 'package:rational/rational.dart';
import 'package:tuple/tuple.dart';

// Matrix values from https://www.w3.org/TR/css-color-4/#color-conversion-code.

enum ColorSpace {
  srgb("srgb", "srgb", gammaCorrected: true),
  displayP3("display-p3", "displayP3", gammaCorrected: true),
  a98Rgb("a98-rgb", "a98Rgb", gammaCorrected: true),
  rec2020("rec2020", "rec2020", gammaCorrected: true),
  prophotoRgb("prophoto-rgb", "prophotoRgb", gammaCorrected: true),
  xyzD65("xyz", "xyzD65", gammaCorrected: false),
  lms("lms", "lms", gammaCorrected: false),
  xyzD50("xyz-d50", "xyzD50", gammaCorrected: false);

  final String cssName;
  final String _dartName;
  final bool gammaCorrected;

  String get humanName => gammaCorrected ? 'linear-light $cssName' : cssName;

  String get dartName =>
      gammaCorrected ? 'linear' + _titleize(_dartName) : _dartName;
  String get dartNameTitleized => _titleize(dartName);

  const ColorSpace(this.cssName, this._dartName,
      {required this.gammaCorrected});

  String _titleize(String ident) => ident[0].toUpperCase() + ident.substring(1);

  String toString() => dartName;
}

final d65 = chromaToXyz(Rational.parse('0.3127'), Rational.parse('0.3290'));
final d50 = chromaToXyz(Rational.parse('0.3457'), Rational.parse('0.3585'));

final linearToXyzD65 = {
  ColorSpace.srgb:
      linearLightRgbToXyz(0.640, 0.330, 0.300, 0.600, 0.150, 0.060, d65),
  ColorSpace.displayP3:
      linearLightRgbToXyz(0.680, 0.320, 0.265, 0.690, 0.150, 0.060, d65),
  ColorSpace.a98Rgb:
      linearLightRgbToXyz(0.6400, 0.3300, 0.2100, 0.7100, 0.1500, 0.0600, d65),
  ColorSpace.rec2020:
      linearLightRgbToXyz(0.708, 0.292, 0.170, 0.797, 0.131, 0.046, d65),
  ColorSpace.xyzD65: RationalMatrix.identity,
  // M1 from https://bottosson.github.io/posts/oklab/#converting-from-xyz-to-oklab
  ColorSpace.lms: RationalMatrix.fromFloat64List(Float64List.fromList([
    0.8190224432164319, 0.3619062562801221, -0.12887378261216414, //
    0.0329836671980271, 0.9292868468965546, 0.03614466816999844,
    0.048177199566046255, 0.26423952494422764, 0.6335478258136937
  ])).invert()
};

final linearToXyzD50 = {
  ColorSpace.prophotoRgb: linearLightRgbToXyz(
      0.734699, 0.265301, 0.159597, 0.840403, 0.036598, 0.000105, d50),
  ColorSpace.xyzD50: RationalMatrix.identity,
};

final bradford = RationalMatrix.fromFloat64List(Float64List.fromList([
  00.8951000, 00.2664000, -0.1614000, //
  -0.7502000, 01.7135000, 00.0367000,
  00.0389000, -0.0685000, 01.0296000
]));

/// The transformation matrix for converting D65 XYZ colors to D50 XYZ.
final RationalMatrix d65XyzToD50 = () {
  // Algorithm from http://www.brucelindbloom.com/index.html?Eqn_ChromAdapt.html
  var source = bradford.timesVector(d65);
  var destination = bradford.timesVector(d50);
  return bradford.invert() *
      RationalMatrix([
        [destination[0] / source[0], Rational.zero, Rational.zero],
        [Rational.zero, destination[1] / source[1], Rational.zero],
        [Rational.zero, Rational.zero, destination[2] / source[2]]
      ]) *
      bradford;
}();

/// The transformation matrix for converting LMS colors to OKLab.
///
/// Note that this can't be directly multiplied with [d65XyzToLms]; see Color
/// Level 4 spec for details on how to convert between XYZ and OKLab.
final lmsToOklab = RationalMatrix.fromFloat64List(Float64List.fromList([
  0.2104542553, 0.7936177850, -0.0040720468, //
  1.9779984951, -2.4285922050, 0.4505937099,
  0.0259040371, 0.7827717662, -0.8086757660
]));

void main() {
  for (var src in linearToXyzD65.entries) {
    for (var dest in linearToXyzD65.entries) {
      printTransform(src.key, dest.key, dest.value.invert() * src.value);
    }

    for (var dest in linearToXyzD50.entries) {
      printTransform(
          src.key, dest.key, dest.value.invert() * d65XyzToD50 * src.value);
    }
  }

  for (var src in linearToXyzD50.entries) {
    for (var dest in linearToXyzD50.entries) {
      printTransform(src.key, dest.key, dest.value.invert() * src.value);
    }
  }
}

final seen = <Tuple2<ColorSpace, ColorSpace>>{};
void printTransform(ColorSpace src, ColorSpace dest, RationalMatrix transform) {
  if (src == dest) return;
  if (!seen.add(Tuple2(src, dest))) return;
  if (!seen.add(Tuple2(dest, src))) return;

  print("// The transformation matrix for converting ${src.humanName} "
      "colors to ${dest.humanName}.");
  print("final ${src}To${dest.dartNameTitleized} = "
      "${transform.toDartString()};");
  print('');

  print("// The transformation matrix for converting ${dest.humanName} "
      "colors to ${src.humanName}.");
  print("final ${dest}To${src.dartNameTitleized} = "
      "${transform.invert().toDartString()};");
  print('');
}

class RationalMatrix {
  static final identity = RationalMatrix([
    [Rational.one, Rational.zero, Rational.zero],
    [Rational.zero, Rational.one, Rational.zero],
    [Rational.zero, Rational.zero, Rational.one]
  ]);

  final List<List<Rational>> contents;

  RationalMatrix(Iterable<Iterable<Rational>> contents)
      : contents = List.unmodifiable(
            contents.map((iter) => List<Rational>.unmodifiable(iter)));

  RationalMatrix.empty()
      : contents = List.generate(3, (_) => List.filled(3, Rational.zero));

  factory RationalMatrix.fromFloat64List(Float64List list) =>
      RationalMatrix(List.generate(
          3,
          (i) => List.generate(
              3, (j) => Rational.parse(list[i * 3 + j].toString()))));

  RationalMatrix operator *(RationalMatrix other) => RationalMatrix([
        for (var i = 0; i < 3; i++)
          [
            for (var j = 0; j < 3; j++)
              [for (var k = 0; k < 3; k++) get(i, k) * other.get(k, j)].sum
          ]
      ]);

  List<Rational> timesVector(List<Rational> vector) => List.generate(
      3, (i) => Iterable.generate(3, (j) => get(i, j) * vector[j]).sum);

  RationalMatrix invert() {
    // Using the same naming convention used in
    // https://en.wikipedia.org/wiki/Determinant and
    // https://en.wikipedia.org/wiki/Invertible_matrix#Inversion_of_3_%C3%97_3_matrices.
    var a = get(0, 0);
    var b = get(0, 1);
    var c = get(0, 2);
    var d = get(1, 0);
    var e = get(1, 1);
    var f = get(1, 2);
    var g = get(2, 0);
    var h = get(2, 1);
    var i = get(2, 2);

    var idet = Rational.one /
        (a * e * i + b * f * g + c * d * h - c * e * g - b * d * i - a * f * h);

    return RationalMatrix([
      [(e * i - f * h) * idet, -(b * i - c * h) * idet, (b * f - c * e) * idet],
      [
        -(d * i - f * g) * idet,
        (a * i - c * g) * idet,
        -(a * f - c * d) * idet
      ],
      [(d * h - e * g) * idet, -(a * h - b * g) * idet, (a * e - b * d) * idet],
    ]);
  }

  RationalMatrix transpose() => RationalMatrix(
      List.generate(3, (i) => List.generate(3, (j) => get(j, i))));

  Rational get(int i, int j) => contents[i][j];

  Rational set(int i, int j, Rational value) => contents[i][j] = value;

  String toString() =>
      '[ ' +
      contents
          .map((row) => row.map((number) => number.toDoubleString()).join(' '))
          .join('\n  ') +
      ' ]';

  String toExactString() =>
      '[ ' +
      contents
          .map((row) => row.map((number) => number.toExactString()).join(' '))
          .join('\n  ') +
      ' ]';

  String toDartString() {
    var buffer = StringBuffer('Float64List.fromList([\n  ');
    var first = true;
    for (var row in contents) {
      if (!first) buffer.write('\n  ');
      buffer.write(row.map((number) => number.toDoubleString()).join(', '));
      buffer.write(',');
      if (first) buffer.write(' //');
      first = false;
    }
    buffer.write('\n])');
    return buffer.toString();
  }
}

const precision = 17;

extension on Rational {
  String toDoubleString() {
    var doubleString = double.parse(toExactString()).toString();
    if (!doubleString.startsWith('-')) doubleString = '0$doubleString';
    return doubleString.toString().padRight(precision + 3, '0');
  }

  String toExactString() {
    var newNum = (Rational(numerator) *
            Rational(BigInt.from(10).pow(precision), denominator))
        .truncate();

    var numString = newNum.abs().toString();
    if (numString.length == precision + 1) {
      numString = '${numString[0]}.${numString.substring(1)}';
    } else {
      numString = '0.${numString.padLeft(precision, '0')}';
    }

    return '${newNum.isNegative ? '-' : '0'}$numString';
  }
}

extension on Iterable<Rational> {
  Rational get sum => reduce((a, b) => a + b);
}

RationalMatrix linearLightRgbToXyz(
        double redChromaX,
        double redChromaY,
        double greenChromaX,
        double greenChromaY,
        double blueChromaX,
        double blueChromaY,
        List<Rational> white) =>
    _linearLightRgbToXyz(
        Rational.parse(redChromaX.toString()),
        Rational.parse(redChromaY.toString()),
        Rational.parse(greenChromaX.toString()),
        Rational.parse(greenChromaY.toString()),
        Rational.parse(blueChromaX.toString()),
        Rational.parse(blueChromaY.toString()),
        white);

RationalMatrix _linearLightRgbToXyz(
    Rational redChromaX,
    Rational redChromaY,
    Rational greenChromaX,
    Rational greenChromaY,
    Rational blueChromaX,
    Rational blueChromaY,
    List<Rational> white) {
  // Algorithm from http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
  var xyzRed = chromaToXyz(redChromaX, redChromaY);
  var xyzGreen = chromaToXyz(greenChromaX, greenChromaY);
  var xyzBlue = chromaToXyz(blueChromaX, blueChromaY);

  var s = RationalMatrix([xyzRed, xyzGreen, xyzBlue])
      .transpose()
      .invert()
      .timesVector(white);
  var sRed = s[0];
  var sGreen = s[1];
  var sBlue = s[2];

  return RationalMatrix([
    xyzRed.map((value) => sRed * value),
    xyzGreen.map((value) => sGreen * value),
    xyzBlue.map((value) => sBlue * value)
  ]).transpose();
}

/// Convert a two-dimensional chroma coordinates into a point in XYZ space.
List<Rational> chromaToXyz(Rational chromaX, Rational chromaY) => [
      chromaX / chromaY,
      Rational.one,
      (Rational.one - chromaX - chromaY) / chromaY
    ];
