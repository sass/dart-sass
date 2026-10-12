// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:sass/src/exception.dart';
import 'package:string_scanner/string_scanner.dart';

import '../parse/parser.dart';
import 'character.dart';

extension StringExtension on String {
  /// Returns a minimally-escaped CSS identifiers whose contents evaluates to
  /// [text].
  ///
  /// If [body] is true, this will not escape characters at the beginning of the
  /// string that are valid in identifier bodies but not at the beginning of
  /// identifiers.
  ///
  /// Throws a [FormatException] if [text] cannot be represented as a CSS
  /// identifier (such as the empty string).
  String toCssIdentifier({bool body = false}) {
    if (_isSimpleIdentifier()) return this;

    var buffer = StringBuffer();
    var scanner = SpanScanner(this);

    void writeHexEscape(int character) {
      buffer.writeCharCode($backslash);
      buffer.write(character.toRadixString(16));
      buffer.writeCharCode($space);
    }

    void consumeSurrogatePair(int character) {
      if (scanner.peekChar(1) case null || int(isLowSurrogate: false)) {
        scanner.error(
          "An individual surrogates can't be represented as a CSS "
          "identifier.",
          length: 1,
        );
      } else if (character.isPrivateUseHighSurrogate) {
        writeHexEscape(
          combineSurrogates(scanner.readChar(), scanner.readChar()),
        );
      } else {
        buffer.writeCharCode(scanner.readChar());
        buffer.writeCharCode(scanner.readChar());
      }
    }

    var doubleDash = false;
    if (!body && scanner.scanChar($dash)) {
      if (scanner.isDone) return '\\2d ';

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
            "The empty string can't be represented as a CSS identifier.",
          );

        case 0:
          scanner.error("U+0000 can't be represented as a CSS identifier.");

        case int character when character.isHighSurrogate:
          consumeSurrogatePair(character);

        case int(isLowSurrogate: true):
          scanner.error(
            "An individual surrogate can't be represented as a CSS "
            "identifier.",
            length: 1,
          );

        case int(isName: true, isPrivateUseBMP: false) when body:
          buffer.writeCharCode(scanner.readChar());

        case int(isNameStart: true, isPrivateUseBMP: false) when !body:
          buffer.writeCharCode(scanner.readChar());

        case <= 0x1f ||
            0x7f ||
            int(isDigit: true) ||
            int(isPrivateUseBMP: true):
          writeHexEscape(scanner.readChar());

        default:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode(scanner.readChar());
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
            length: 1,
          );

        case int(isName: true, isPrivateUseBMP: false):
          buffer.writeCharCode(scanner.readChar());

        case <= 0x1f || 0x7f || int(isPrivateUseBMP: true):
          writeHexEscape(scanner.readChar());

        default:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode(scanner.readChar());
      }
    }

    return buffer.toString();
  }

  /// Interprets this string as a CSS identifier and resolves any escape codes
  /// it contains.
  ///
  /// Throws an [ArgumentError] if this isn't a valid CSS identifier.
  String resolveCssEscapes() {
    if (_isSimpleIdentifier()) return this;
    try {
      return Parser.parseIdentifier(this);
    } on SassFormatException catch (_) {
      throw ArgumentError('"$this" isn\'t a valid CSS identifier');
    }
  }

  /// Returns whether this is a valid CSS identifier that has the same semantic
  /// content as the string itself.
  ///
  /// This is intended to be a quick check to use for optimizations. It can
  /// return false negatives, but not false positives.
  bool _isSimpleIdentifier() {
    if (length == 0) return false;
    var codeUnit = codeUnitAt(0);
    if (!codeUnit.isNameStart ||
        codeUnit.isPrivateUseBMP ||
        codeUnit.isLowSurrogate ||
        codeUnit.isHighSurrogate) {
      return false;
    }

    for (var i = 1; i < length; i++) {
      var codeUnit = codeUnitAt(i);
      if (!codeUnit.isName ||
          codeUnit.isPrivateUseBMP ||
          codeUnit.isLowSurrogate ||
          codeUnit.isHighSurrogate) {
        return false;
      }
    }
    return true;
  }
}
