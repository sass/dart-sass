// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

// `0b100000` can be bitwise-ORed with lowercase ASCII letters to get their
// uppercase equivalents.
const _asciiCaseBit = 0x20;

bool isWhitespace(int character) =>
    character == $space || character == $tab || isNewline(character);

bool isNewline(int character) =>
    character == $lf || character == $cr || character == $ff;

bool isAlphanumeric(int character) =>
    isAlphabetic(character) || isDigit(character);

bool isAlphabetic(int character) =>
    (character >= $a && character <= $z) ||
    (character >= $A && character <= $Z);

bool isDigit(int character) => character >= $0 && character <= $9;

bool isNameStart(int character) =>
    character == $_ || isAlphabetic(character) || character >= 0x0080;

bool isName(int character) =>
    isNameStart(character) || isDigit(character) || character == $minus;

bool isHex(int character) =>
    isDigit(character) ||
    (character >= $a && character <= $f) ||
    (character >= $A && character <= $F);

bool isHighSurrogate(int character) =>
    character >= 0xD800 && character <= 0xDBFF;

// Does not include type selectors
bool isSimpleSelectorStart(int character) =>
    character == $asterisk ||
    character == $lbracket ||
    character == $dot ||
    character == $hash ||
    character == $colon;

int asHex(int character) {
  if (character <= $9) return character - $0;
  if (character <= $F) return 10 + character - $A;
  return 10 + character - $a;
}

int hexCharFor(int character) {
  assert(character < 0x10);
  return character < 0xA ? $0 + character : $a - 0xA + character;
}

int opposite(int character) {
  switch (character) {
    case $lparen:
      return $rparen;
    case $lbrace:
      return $rbrace;
    case $lbracket:
      return $rbracket;
    default:
      return null;
  }
}

bool characterEqualsIgnoreCase(int character1, int character2) {
  if (character1 == character2) return true;

  // If this check fails, the characters are definitely different. If it
  // succeeds *and* either character is an ASCII letter, they're equivalent.
  if (character1 ^ character2 != _asciiCaseBit) return false;

  // Now we just need to verify that one of the characters is an ASCII letter.
  var upperCase1 = character1 | _asciiCaseBit;
  return upperCase1 >= $A && upperCase1 <= $Z;
}

/// Like [characterEqualsIgnoreCase], but optimized for the fact that [letter]
/// is known to be a lowercase ASCII letter.
bool equalsLetterIgnoreCase(int letter, int actual) {
  assert(letter >= $a && letter <= $z);
  return (actual & ~_asciiCaseBit) == letter;
}
