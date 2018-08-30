// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/sass.dart';
import '../functions.dart';
import '../logger.dart';
import 'scss.dart';

/// The set of all function names disallowed in plain CSS.
final _disallowedFunctionNames =
    coreFunctions.map((function) => function.name).toSet()
      ..add("if")
      ..remove("rgb")
      ..remove("rgba")
      ..remove("hsl")
      ..remove("hsla")
      ..remove("grayscale")
      ..remove("invert")
      ..remove("alpha")
      ..remove("opacity");

class CssParser extends ScssParser {
  bool get plainCss => true;

  CssParser(String contents, {url, Logger logger})
      : super(contents, url: url, logger: logger);

  void silentComment() {
    var start = scanner.state;
    super.silentComment();
    error("Silent comments aren't allowed in plain CSS.",
        scanner.spanFrom(start));
  }

  Statement atRule(Statement child(), {bool root: false}) {
    // NOTE: this logic is largely duplicated in CssParser.atRule. Most changes
    // here should be mirrored there.

    var start = scanner.state;
    var name = atRuleName();

    switch (name) {
      case "at-root":
      case "content":
      case "debug":
      case "each":
      case "error":
      case "extend":
      case "for":
      case "function":
      case "if":
      case "include":
      case "mixin":
      case "return":
      case "warn":
      case "while":
        almostAnyValue();
        error("This at-rule isn't allowed in plain CSS.",
            scanner.spanFrom(start));
        break;

      case "charset":
        string();
        if (!root) {
          error("This at-rule is not allowed here.", scanner.spanFrom(start));
        }
        return null;
      case "import":
        return _cssImportRule(start);
      case "media":
        return mediaRule(start);
      case "-moz-document":
        return mozDocumentRule(start);
      case "supports":
        return supportsRule(start);
      default:
        return unknownAtRule(start, name);
    }
  }

  /// Consumes a plain-CSS `@import` rule that disallows interpolation.
  ///
  /// [start] should point before the `@`.
  ImportRule _cssImportRule(LineScannerState start) {
    var urlStart = scanner.state;
    var next = scanner.peekChar();
    Expression url;
    if (next == $u || next == $U) {
      url = dynamicUrl();
    } else {
      url = new StringExpression(
          interpolatedString().asInterpolation(static: true));
    }
    var urlSpan = scanner.spanFrom(urlStart);

    whitespace();
    var queries = tryImportQueries();
    expectStatementSeparator("@import rule");
    return new ImportRule([
      new StaticImport(
          new Interpolation([url], urlSpan), scanner.spanFrom(urlStart),
          supports: queries?.item1, media: queries?.item2)
    ], scanner.spanFrom(start));
  }

  Expression identifierLike() {
    var start = scanner.state;
    var identifier = interpolatedIdentifier();
    var plain = identifier.asPlain;

    var specialFunction = trySpecialFunction(plain.toLowerCase(), start);
    if (specialFunction != null) return specialFunction;

    var beforeArguments = scanner.state;
    if (!scanner.scanChar($lparen)) return new StringExpression(identifier);

    var arguments = <Expression>[];
    if (!scanner.scanChar($rparen)) {
      do {
        whitespace();
        arguments.add(expression(singleEquals: true));
        whitespace();
      } while (scanner.scanChar($comma));
      scanner.expectChar($rparen);
    }

    if (_disallowedFunctionNames.contains(plain)) {
      error(
          "This function isn't allowed in plain CSS.", scanner.spanFrom(start));
    }

    return new FunctionExpression(
        // Create a fake interpolation to force the function to be interpreted
        // as plain CSS, rather than calling a user-defined function.
        new Interpolation([new StringExpression(identifier)], identifier.span),
        new ArgumentInvocation(
            arguments, const {}, scanner.spanFrom(beforeArguments)));
  }
}
