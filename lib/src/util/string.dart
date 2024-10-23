// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import 'character.dart';

extension StringExtension on String {
  /// Returns a minimally-escaped CSS identifiers whose contents evaluates to
  /// [text].
  ///
  /// Throws a [FormatException] if [text] cannot be represented as a CSS
  /// identifier (such as the empty string).
  String toCssIdentifier() {
    var buffer = StringBuffer();
    var scanner = SpanScanner(this);

    void writeEscape(int character) {
      buffer.writeCharCode($backslash);
      buffer.write(character.toRadixString(16));
      if (scanner.peekChar() case int(isHex: true)) {
        buffer.writeCharCode($space);
      }
    }

    void consumeSurrogatePair(int character) {
      if (scanner.peekChar(1) case null || int(isLowSurrogate: false)) {
        scanner.error(
            "An individual surrogates can't be represented as a CSS "
            "identifier.",
            length: 1);
      } else if (character.isPrivateUseHighSurrogate) {
        writeEscape(combineSurrogates(scanner.readChar(), scanner.readChar()));
      } else {
        buffer.writeCharCode(scanner.readChar());
        buffer.writeCharCode(scanner.readChar());
      }
    }

    var doubleDash = false;
    if (scanner.scanChar($dash)) {
      if (scanner.isDone) return '\\2d';

      buffer.writeCharCode($dash);

      if (scanner.scanChar($dash)) {
        buffer.writeCharCode($dash);
        doubleDash = true;
      }
    }

    if (!doubleDash) {
      switch (scanner.peekChar()) {
        case null:
          scanner.error(
              "The empty string can't be represented as a CSS identifier.");

        case 0:
          scanner.error("The U+0000 can't be represented as a CSS identifier.");

        case int character when character.isHighSurrogate:
          consumeSurrogatePair(character);

        case int(isLowSurrogate: true):
          scanner.error(
              "An individual surrogate can't be represented as a CSS "
              "identifier.",
              length: 1);

        case int(isNameStart: true, isPrivateUseBMP: false):
          buffer.writeCharCode(scanner.readChar());

        case _:
          writeEscape(scanner.readChar());
      }
    }

    loop:
    while (true) {
      switch (scanner.peekChar()) {
        case null:
          break loop;

        case 0:
          scanner.error("The U+0000 can't be represented as a CSS identifier.");

        case int character when character.isHighSurrogate:
          consumeSurrogatePair(character);

        case int(isLowSurrogate: true):
          scanner.error(
              "An individual surrogate can't be represented as a CSS "
              "identifier.",
              length: 1);

        case int(isName: true, isPrivateUseBMP: false):
          buffer.writeCharCode(scanner.readChar());

        case _:
          writeEscape(scanner.readChar());
      }
    }

    return buffer.toString();
  }
}
