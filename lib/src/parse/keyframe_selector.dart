// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../util/character.dart';
import 'parser.dart';

/// A parser for `@keyframes` block selectors.
class KeyframeSelectorParser extends Parser {
  KeyframeSelectorParser(super.contents, {super.url, super.interpolationMap});

  List<String> parse() {
    return wrapSpanFormatException(() {
      var selectors = <String>[];
      do {
        whitespace();
        if (lookingAtIdentifier()) {
          if (scanIdentifier("from")) {
            selectors.add("from");
          } else {
            expectIdentifier("to", name: '"to" or "from"');
            selectors.add("to");
          }
        } else {
          selectors.add(_percentage());
        }
        whitespace();
      } while (scanner.scanChar($comma));
      scanner.expectDone();

      return selectors;
    });
  }

  String _percentage() {
    var buffer = StringBuffer();
    if (scanner.scanChar($plus)) buffer.writeCharCode($plus);

    var second = scanner.peekChar();
    if (!second.isDigit && second != $dot) {
      scanner.error("Expected number.");
    }

    while (scanner.peekChar().isDigit) {
      buffer.writeCharCode(scanner.readChar());
    }

    if (scanner.peekChar() == $dot) {
      buffer.writeCharCode(scanner.readChar());

      while (scanner.peekChar().isDigit) {
        buffer.writeCharCode(scanner.readChar());
      }
    }

    if (scanIdentChar($e)) {
      buffer.writeCharCode($e);
      if (scanner.peekChar() case $plus || $minus) {
        buffer.writeCharCode(scanner.readChar());
      }
      if (!scanner.peekChar().isDigit) scanner.error("Expected digit.");

      do {
        buffer.writeCharCode(scanner.readChar());
      } while (scanner.peekChar().isDigit);
    }

    scanner.expectChar($percent);
    buffer.writeCharCode($percent);
    return buffer.toString();
  }
}
