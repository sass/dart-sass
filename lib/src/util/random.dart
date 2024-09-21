import 'dart:math' show Random;

Random _random = Random();

Random get random => _random;

void setRandomSeed(int? seed) {
  _random = Random(seed);
}
