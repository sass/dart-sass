// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import '../interpolation_map.dart';
import '../logger.dart';
import 'parser.dart';

/// A parser for `@at-root` queries.
class AtRootQueryParser extends Parser {
  AtRootQueryParser(String contents,
      {Object? url, Logger? logger, InterpolationMap? interpolationMap})
      : super(contents,
            url: url, logger: logger, interpolationMap: interpolationMap);

  AtRootQuery parse() {
    return wrapSpanFormatException(() {
      scanner.expectChar($lparen);
      whitespace();
      var include = scanIdentifier("with");
      if (!include) expectIdentifier("without", name: '"with" or "without"');
      whitespace();
      scanner.expectChar($colon);
      whitespace();

      var atRules = <String>{};
      do {
        atRules.add(identifier().toLowerCase());
        whitespace();
      } while (lookingAtIdentifier());
      scanner.expectChar($rparen);
      scanner.expectDone();

      return AtRootQuery(atRules, include: include);
    });
  }
}
