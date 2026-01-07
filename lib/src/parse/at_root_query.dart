// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:meta/meta.dart';

import '../ast/sass.dart';
import 'parser.dart';

/// A parser for `@at-root` queries.
@internal
final class AtRootQueryParser extends Parser {
  AtRootQueryParser(super.contents, {super.url, super.interpolationMap});

  AtRootQuery parse() {
    return wrapSpanFormatException(() {
      scanner.expectChar($lparen);
      _whitespace();
      var include = scanIdentifier("with");
      if (!include) expectIdentifier("without", name: '"with" or "without"');
      _whitespace();
      scanner.expectChar($colon);
      _whitespace();

      var atRules = <String>{};
      do {
        atRules.add(identifier().toLowerCase());
        _whitespace();
      } while (lookingAtIdentifier());
      scanner.expectChar($rparen);
      scanner.expectDone();

      return AtRootQuery(atRules, include: include);
    });
  }

  /// The value of `consumeNewlines` is not relevant for this class.
  void _whitespace() {
    whitespace(consumeNewlines: true);
  }
}
