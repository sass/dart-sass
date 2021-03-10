// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

/// The difference between upper- and lowercase ASCII letters.
///
/// `0b100000` can be bitwise-ORed with uppercase ASCII letters to get their
/// lowercase equivalents.
const _asciiCaseBit = 0x20;

/// Returns whether [character] is an ASCII whitespace character.
bool isWhitespace(int character) =>
    isSpaceOrTab(character) || isNewline(character);

/// Returns whether [character] is an ASCII newline.
bool isNewline(int character) =>
    character == $lf || character == $cr || character == $ff;

/// Returns whether [character] is a space or a tab character.
bool isSpaceOrTab(int character) => character == $space || character == $tab;

/// Returns whether [character] is a letter or number.
bool isAlphanumeric(int character) =>
    isAlphabetic(character) || isDigit(character);

/// Returns whether [character] is a letter.
bool isAlphabetic(int character) =>
    (character >= $a && character <= $z) ||
    (character >= $A && character <= $Z);

/// Returns whether [character] is a number.
bool isDigit(int character) =>
    character != null && character >= $0 && character <= $9;

/// Returns whether [character] is legal as the start of a Sass identifier.
bool isNameStart(int character) =>
    character == $_ || isAlphabetic(character) || character >= 0x0080;

/// Returns whether [character] is legal in the body of a Sass identifier.
bool isName(int character) =>
    isNameStart(character) || isDigit(character) || character == $minus;

/// Returns whether [character] is a hexadeicmal digit.
bool isHex(int character) {
  if (character == null) return false;
  if (isDigit(character)) return true;
  if (character >= $a && character <= $f) return true;
  if (character >= $A && character <= $F) return true;
  return false;
}

/// Returns whether [character] is the beginning of a UTF-16 surrogate pair.
bool isHighSurrogate(int character) =>
    character >= 0xD800 && character <= 0xDBFF;

// Returns whether [character] can start a simple selector other than a type
// selector.
bool isSimpleSelectorStart(int character) =>
    character == $asterisk ||
    character == $lbracket ||
    character == $dot ||
    character == $hash ||
    character == $percent ||
    character == $colon;

/// Returns whether [identifier] is module-private.
///
/// Assumes [identifier] is a valid Sass identifier.
bool isPrivate(String identifier) {
  var first = identifier.codeUnitAt(0);
  return first == $dash || first == $underscore;
}

/// Returns the value of [character] as a hex digit.
///
/// Assumes that [character] is a hex digit.
int asHex(int character) {
  assert(isHex(character));
  if (character <= $9) return character - $0;
  if (character <= $F) return 10 + character - $A;
  return 10 + character - $a;
}

/// Returns the hexadecimal digit for [number].
///
/// Assumes that [number] is less than 16.
int hexCharFor(int number) {
  assert(number < 0x10);
  return number < 0xA ? $0 + number : $a - 0xA + number;
}

/// Returns the value of [character] as a decimal digit.
///
/// Assumes that [character] is a decimal digit.
int asDecimal(int character) {
  assert(character >= $0 && character <= $9);
  return character - $0;
}

/// Returns the decimal digit for [number].
///
/// Assumes that [number] is less than 10.
int decimalCharFor(int number) {
  assert(number < 10);
  return $0 + number;
}

/// Assumes that [character] is a left-hand brace-like character, and returns
/// the right-hand version.
int opposite(int character) {
  switch (character) {
    case $lparen:
      return $rparen;
    case $lbrace:
      return $rbrace;
    case $lbracket:
      return $rbracket;
    default:
      throw ArgumentError(
          '"${String.fromCharCode(character)}" isn\'t a brace-like character.');
  }
}

/// Returns [character], converted to upper case if it's an ASCII lowercase
/// letter.
int toUpperCase(int character) => (character >= $a && character <= $z)
    ? character & ~_asciiCaseBit
    : character;

/// Returns [character], converted to lower case if it's an ASCII uppercase
/// letter.
int toLowerCase(int character) => (character >= $A && character <= $Z)
    ? character | _asciiCaseBit
    : character;

/// Returns whether [character1] and [character2] are the same, modulo ASCII case.
bool characterEqualsIgnoreCase(int character1, int character2) {
  if (character1 == character2) return true;

  // If this check fails, the characters are definitely different. If it
  // succeeds *and* either character is an ASCII letter, they're equivalent.
  if (character1 ^ character2 != _asciiCaseBit) return false;

  // Now we just need to verify that one of the characters is an ASCII letter.
  var upperCase1 = character1 & ~_asciiCaseBit;
  return upperCase1 >= $A && upperCase1 <= $Z;
}

/// Like [characterEqualsIgnoreCase], but optimized for the fact that [letter]
/// is known to be a lowercase ASCII letter.
bool equalsLetterIgnoreCase(int letter, int actual) {
  assert(letter >= $a && letter <= $z);
  return (actual | _asciiCaseBit) == letter;
}
