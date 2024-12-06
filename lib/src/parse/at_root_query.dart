// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import 'parser.dart';

/// A parser for `@at-root` queries.
class AtRootQueryParser extends Parser {
  AtRootQueryParser(super.contents, {super.url, super.interpolationMap});

  AtRootQuery parse() {
    return wrapSpanFormatException(() {
      scanner.expectChar($lparen);
      // TODO: No tests
      whitespace(consumeNewlines: true);
      var include = scanIdentifier("with");
      if (!include) expectIdentifier("without", name: '"with" or "without"');
      whitespace(consumeNewlines: true);
      scanner.expectChar($colon);
      whitespace(consumeNewlines: true);

      var atRules = <String>{};
      do {
        atRules.add(identifier().toLowerCase());
        whitespace(consumeNewlines: true);
      } while (lookingAtIdentifier());
      scanner.expectChar($rparen);
      scanner.expectDone();

      return AtRootQuery(atRules, include: include);
    });
  }
}
