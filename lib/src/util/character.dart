// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

/// The difference between upper- and lowercase ASCII letters.
///
/// `0b100000` can be bitwise-ORed with uppercase ASCII letters to get their
/// lowercase equivalents.
const _asciiCaseBit = 0x20;

/// The highest character allowed in a
const maxAllowedCharacter = 0x10FFFF;

// Define these checks as extension getters so they can be used in pattern
// matches.
extension CharacterExtension on int {
  /// Returns whether [character] is a letter or number.
  bool get isAlphanumeric => isAlphabetic || isDigit;

  /// Returns whether [character] is a letter.
  bool get isAlphabetic =>
      (this >= $a && this <= $z) || (this >= $A && this <= $Z);

  /// Returns whether [character] is a number.
  bool get isDigit => this >= $0 && this <= $9;

  /// Returns whether [character] is legal as the start of a Sass identifier.
  bool get isNameStart => this == $_ || isAlphabetic || this >= 0x0080;

  /// Returns whether [character] is legal in the body of a Sass identifier.
  bool get isName => isNameStart || isDigit || this == $minus;

  /// Returns whether [character] is the beginning of a UTF-16 surrogate pair.
  bool get isHighSurrogate =>
      // A character is a high surrogate exactly if it matches 0b110110XXXXXXXXXX.
      // 0x36 == 0b110110.
      this >> 10 == 0x36;

  /// Returns whether [character] is the end of a UTF-16 surrogate pair.
  bool get isLowSurrogate =>
      // A character is a high surrogate exactly if it matches 0b110111XXXXXXXXXX.
      // 0x36 == 0b110111.
      this >> 10 == 0x37;

  /// Returns whether [character] is a Unicode private-use code point in the Basic
  /// Multilingual Plane.
  ///
  /// See https://en.wikipedia.org/wiki/Private_Use_Areas for details.
  bool get isPrivateUseBMP => this >= 0xE000 && this <= 0xF8FF;

  /// Returns whether [character] is the high surrogate for a code point in a
  /// Unicode private-use supplementary plane.
  ///
  /// See https://en.wikipedia.org/wiki/Private_Use_Areas for details.
  bool get isPrivateUseHighSurrogate =>
      // Supplementary Private Use Area-A's and B's high surrogates range from
      // 0xDB80 to 0xDBFF, which covers exactly the range 0b110110111XXXXXXX.
      // 0b110110111 == 0x1B7.
      this >> 7 == 0x1B7;

  /// Returns whether [character] is a hexadecimal digit.
  bool get isHex =>
      isDigit || (this >= $a && this <= $f) || (this >= $A && this <= $F);
}

// Like [CharacterExtension], but these are defined on nullable ints because
// they only use equality comparisons.
//
// This also extends a few [CharacterExtension] getters to return `false` for
// null values.
extension NullableCharacterExtension on int? {
  /// Returns whether [character] is an ASCII whitespace character.
  bool get isWhitespace => isSpaceOrTab || isNewline;

  /// Returns whether [character] is an ASCII newline.
  bool get isNewline => this == $lf || this == $cr || this == $ff;

  /// Returns whether [character] is a space or a tab character.
  bool get isSpaceOrTab => this == $space || this == $tab;

  /// Returns whether [character] is a number.
  bool get isDigit {
    var self = this;
    return self != null && self.isDigit;
  }

  /// Returns whether [character] is a hexadecimal digit.
  bool get isHex {
    var self = this;
    return self != null && self.isHex;
  }
}

/// Combines a UTF-16 high and low surrogate pair into a single code unit.
///
/// See https://en.wikipedia.org/wiki/UTF-16 for details.
int combineSurrogates(int highSurrogate, int lowSurrogate) =>
    // 0x3FF == 0b0000001111111111, which masks out the six bits that indicate
    // high/low surrogates.
    0x10000 + ((highSurrogate & 0x3FF) << 10) + (lowSurrogate & 0x3FF);

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
  assert(character.isHex);
  return switch (character) {
    // dart-lang/sdk#52740
    // ignore: non_constant_relational_pattern_expression
    <= $9 => character - $0,
    // ignore: non_constant_relational_pattern_expression
    <= $F => 10 + character - $A,
    _ => 10 + character - $a
  };
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
  assert(number < 10, "Expected $number to be a digit from 0 to 9.");
  return $0 + number;
}

/// Assumes that [character] is a left-hand brace-like character, and returns
/// the right-hand version.
int opposite(int character) => switch (character) {
      $lparen => $rparen,
      $lbrace => $rbrace,
      $lbracket => $rbracket,
      _ => throw ArgumentError(
          '"${String.fromCharCode(character)}" isn\'t a brace-like character.')
    };

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
