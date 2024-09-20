import 'dart:math' show Random;

export 'dart:math' show Random;

late Random _random;

Random get random => _random;

void setRandomSeed(int? seed) {
  _random = Random(seed);
}
