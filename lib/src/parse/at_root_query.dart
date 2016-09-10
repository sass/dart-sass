// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../ast/sass.dart';
import 'parser.dart';

class AtRootQueryParser extends Parser {
  AtRootQueryParser(String contents, {url}) : super(contents, url: url);

  AtRootQuery parse() {
    return wrapFormatException(() {
      scanner.expectChar($lparen);
      whitespace();
      expectIdentifier("with", ignoreCase: true);
      var include = !scanIdentifier("out", ignoreCase: true);
      whitespace();
      scanner.expectChar($colon);
      whitespace();

      var atRules = new Set<String>();
      do {
        atRules.add(identifier().toLowerCase());
        whitespace();
      } while (lookingAtIdentifier());

      return new AtRootQuery(include, atRules);
    });
  }
}
