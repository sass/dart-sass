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
  MediaQueryParser(String contents, {Object? url, Logger? logger})
      : super(contents, url: url, logger: logger);

  List<CssMediaQuery> parse() {
    return wrapSpanFormatException(() {
      var queries = <CssMediaQuery>[];
      do {
        whitespace();
        queries.add(_mediaQuery());
        whitespace();
      } while (scanner.scanChar($comma));
      scanner.expectDone();
      return queries;
    });
  }

  /// Consumes a single media query.
  CssMediaQuery _mediaQuery() {
    // This is somewhat duplicated in StylesheetParser._mediaQuery.
    if (scanner.peekChar() == $lparen) {
      var conditions = [_mediaInParens()];
      whitespace();

      var conjunction = true;
      if (scanIdentifier("and")) {
        expectWhitespace();
        conditions.addAll(_mediaLogicSequence("and"));
      } else if (scanIdentifier("or")) {
        expectWhitespace();
        conjunction = false;
        conditions.addAll(_mediaLogicSequence("or"));
      }

      return CssMediaQuery.condition(conditions, conjunction: conjunction);
    }

    String? modifier;
    String? type;
    var identifier1 = identifier();

    if (equalsIgnoreCase(identifier1, "not")) {
      expectWhitespace();
      if (!lookingAtIdentifier()) {
        // For example, "@media not (...) {"
        return CssMediaQuery.condition(["(not ${_mediaInParens()})"]);
      }
    }

    whitespace();
    if (!lookingAtIdentifier()) {
      // For example, "@media screen {"
      return CssMediaQuery.type(identifier1);
    }

    var identifier2 = identifier();

    if (equalsIgnoreCase(identifier2, "and")) {
      expectWhitespace();
      // For example, "@media screen and ..."
      type = identifier1;
    } else {
      whitespace();
      modifier = identifier1;
      type = identifier2;
      if (scanIdentifier("and")) {
        // For example, "@media only screen and ..."
        expectWhitespace();
      } else {
        // For example, "@media only screen {"
        return CssMediaQuery.type(type, modifier: modifier);
      }
    }

    // We've consumed either `IDENTIFIER "and"` or
    // `IDENTIFIER IDENTIFIER "and"`.

    if (scanIdentifier("not")) {
      // For example, "@media screen and not (...) {"
      expectWhitespace();
      return CssMediaQuery.type(type,
          modifier: modifier, conditions: ["(not ${_mediaInParens()})"]);
    }

    return CssMediaQuery.type(type,
        modifier: modifier, conditions: _mediaLogicSequence("and"));
  }

  /// Consumes one or more `<media-in-parens>` expressions separated by
  /// [operator] and returns them.
  List<String> _mediaLogicSequence(String operator) {
    var result = <String>[];
    while (true) {
      result.add(_mediaInParens());
      whitespace();

      if (!scanIdentifier(operator)) return result;
      expectWhitespace();
    }
  }

  /// Consumes a `<media-in-parens>` expression and returns it, parentheses
  /// included.
  String _mediaInParens() {
    scanner.expectChar($lparen, name: "media condition in parentheses");
    var result = "(${declarationValue()})";
    scanner.expectChar($rparen);
    return result;
  }
}
