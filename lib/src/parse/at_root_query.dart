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
      ignoreComments();
      expectIdentifier("with", ignoreCase: true);
      var include = !scanIdentifier("out", ignoreCase: true);
      ignoreComments();
      scanner.expectChar($colon);
      ignoreComments();

      var atRules = new Set<String>();
      do {
        atRules.add(identifier().toLowerCase());
        ignoreComments();
      } while (lookingAtIdentifier());

      return new AtRootQuery(include, atRules);
    });
  }
}
