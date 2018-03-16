// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/css.dart';
import '../logger.dart';
import '../utils.dart';
import 'parser.dart';

/// A parser for `@media` queries.
class MediaQueryParser extends Parser {
  MediaQueryParser(String contents, {url, Logger logger})
      : super(contents, url: url, logger: logger);

  List<CssMediaQuery> parse() {
    return wrapSpanFormatException(() {
      var queries = <CssMediaQuery>[];
      do {
        whitespace();
        queries.add(_mediaQuery());
      } while (scanner.scanChar($comma));
      scanner.expectDone();
      return queries;
    });
  }

  /// Consumes a single media query.
  CssMediaQuery _mediaQuery() {
    // This is somewhat duplicated in StylesheetParser._mediaQuery.
    String modifier;
    String type;
    if (scanner.peekChar() != $lparen) {
      var identifier1 = identifier();
      whitespace();

      if (!lookingAtIdentifier()) {
        // For example, "@media screen {"
        return new CssMediaQuery(identifier1);
      }

      var identifier2 = identifier();
      whitespace();

      if (equalsIgnoreCase(identifier2, "and")) {
        // For example, "@media screen and ..."
        type = identifier1;
      } else {
        modifier = identifier1;
        type = identifier2;
        if (scanIdentifier("and", ignoreCase: true)) {
          // For example, "@media only screen and ..."
          whitespace();
        } else {
          // For example, "@media only screen {"
          return new CssMediaQuery(type, modifier: modifier);
        }
      }
    }

    // We've consumed either `IDENTIFIER "and"`, `IDENTIFIER IDENTIFIER "and"`,
    // or no text.

    var features = <String>[];
    do {
      whitespace();
      scanner.expectChar($lparen);
      features.add("(${declarationValue()})");
      scanner.expectChar($rparen);
      whitespace();
    } while (scanIdentifier("and", ignoreCase: true));

    if (type == null) {
      return new CssMediaQuery.condition(features);
    } else {
      return new CssMediaQuery(type, modifier: modifier, features: features);
    }
  }
}
