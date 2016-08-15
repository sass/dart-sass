// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

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

bool isHex(int character) =>
    isDigit(character) ||
    (character >= $a && character <= $f) ||
    (character >= $A && character <= $F);

bool isExpressionStart(int character) =>
    character == $lparen || character == $slash || character == $dot ||
    character == $lbracket || character == $single_quote ||
    character == $double_quote || character == $hash || character == $plus ||
    character == $minus || character == $backslash || character == $dollar ||
    isNameStart(character) || isDigit(character);

// Does not include type selectors
bool isSimpleSelectorStart(int character) =>
    character == $asterisk || character == $lbracket || character == $dot ||
    character == $hash || character == $colon;

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
    case $lparen: return $rparen;
    case $lbrace: return $rbrace;
    case $lbracket: return $rbracket;
    default: return null;
  }
}
