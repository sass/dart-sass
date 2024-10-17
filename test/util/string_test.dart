// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass/src/util/string.dart';
import 'package:sass/src/util/map.dart';

void main() {
  group("toCssIdentifier()", () {
    group("doesn't escape", () {
      test('a double hyphen',
          () => expect('--'.toCssIdentifier(), equals('--')));

      group("a starting character", () {
        const chars = {
          'lower-case alphabetic': 'q',
          'upper-case alphabetic': 'E',
          'an underscore': '_',
          'non-ASCII': 'ä',
          'double-width': '👭'
        };

        group("at the very beginning that's", () {
          for (var (name, char) in chars.pairs) {
            test(name, () => expect(char.toCssIdentifier(), equals(char)));
          }
        });

        group("after a single hyphen that's", () {
          for (var (name, char) in chars.pairs) {
            test(name,
                () => expect('-$char'.toCssIdentifier(), equals('-$char')));
          }
        });
      });

      group("a middle character", () {
        const chars = {
          'lower-case alphabetic': 'q',
          'upper-case alphabetic': 'E',
          'numeric': '4',
          'an underscore': '_',
          'a hyphen': '-',
          'non-ASCII': 'ä',
          'double-width': '👭'
        };

        group("after a name start that's", () {
          for (var (name, char) in chars.pairs) {
            test(name,
                () => expect('a$char'.toCssIdentifier(), equals('a$char')));
          }
        });

        group("after a double hyphen that's", () {
          for (var (name, char) in chars.pairs) {
            test(name,
                () => expect('--$char'.toCssIdentifier(), equals('--$char')));
          }
        });
      });
    });

    group('escapes', () {
      test('a single hyphen',
          () => expect('-'.toCssIdentifier(), equals('\\2d')));

      group('a starting character', () {
        const chars = {
          'numeric': ('4', '\\34'),
          'non-alphanumeric ASCII': ('%', '\\25'),
          'a BMP private-use character': ('\ueabc', '\\eabc'),
          'a supplementary private-use character': ('\u{fabcd}', '\\fabcd'),
        };

        group("at the very beginning that's", () {
          for (var (name, (char, escape)) in chars.pairs) {
            test(
                name, () => expect(char.toCssIdentifier(), equals('$escape')));
          }
        });

        group("after a single hyphen that's", () {
          for (var (name, (char, escape)) in chars.pairs) {
            test(name,
                () => expect('-$char'.toCssIdentifier(), equals('-$escape')));
          }
        });
      });

      group('a middle character', () {
        const chars = {
          'non-alphanumeric ASCII': ('%', '\\25'),
          'a BMP private-use character': ('\ueabc', '\\eabc'),
          'a supplementary private-use character': ('\u{fabcd}', '\\fabcd'),
        };

        group("after a name start that's", () {
          for (var (name, (char, escape)) in chars.pairs) {
            test(name,
                () => expect('a$char'.toCssIdentifier(), equals('a$escape')));
          }
        });

        group("after a double hyphen that's", () {
          for (var (name, (char, escape)) in chars.pairs) {
            test(
                name,
                () =>
                    expect('--$char'.toCssIdentifier(), equals('--$escape')));
          }
        });
      });
    });

    group('throws an error for', () {
      test('the empty string',
          () => expect(''.toCssIdentifier, throwsFormatException));

      const chars = {
        'zero': '\u0000',
        'single high surrogate': '\udabc',
        'single low surrogate': '\udcde',
      };

      group("a starting character that's", () {
        for (var (name, char) in chars.pairs) {
          test(name, () => expect(char.toCssIdentifier, throwsFormatException));
        }
      });

      group("after a hyphen that's", () {
        for (var (name, char) in chars.pairs) {
          test(name,
              () => expect('-$char'.toCssIdentifier, throwsFormatException));
        }
      });

      group("after a name start that's", () {
        for (var (name, char) in chars.pairs) {
          test(name,
              () => expect('a$char'.toCssIdentifier, throwsFormatException));
        }
      });

      group("after a double hyphen that's", () {
        for (var (name, char) in chars.pairs) {
          test(name,
              () => expect('--$char'.toCssIdentifier, throwsFormatException));
        }
      });

      group("before a body char that's", () {
        for (var (name, char) in chars.pairs) {
          test(name,
              () => expect('a${char}b'.toCssIdentifier, throwsFormatException));
        }
      });
    });

    group('adds a space between an escape and', () {
      test('a digit', () => expect(' 1'.toCssIdentifier(), '\\20 1'));

      test('a lowercase hex letter',
          () => expect(' b'.toCssIdentifier(), '\\20 b'));

      test('an uppercase hex letter',
          () => expect(' B'.toCssIdentifier(), '\\20 B'));
    });

    group('doesn\'t add a space between an escape and', () {
      test('the end of the string',
          () => expect(' '.toCssIdentifier(), '\\20'));

      test('a lowercase non-hex letter',
          () => expect(' g'.toCssIdentifier(), '\\20g'));

      test('an uppercase non-hex letter',
          () => expect(' G'.toCssIdentifier(), '\\20G'));

      test('a hyphen', () => expect(' -'.toCssIdentifier(), '\\20-'));

      test('a non-ascii character',
          () => expect(' ä'.toCssIdentifier(), '\\20ä'));

      test('another escape', () => expect('  '.toCssIdentifier(), '\\20\\20'));
    });
  });
}
