// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:string_scanner/string_scanner.dart';

import '../ast/sass.dart';
import '../functions.dart';
import '../interpolation_buffer.dart';
import 'scss.dart';

/// The set of all function names disallowed in plain CSS.
final _disallowedFunctionNames =
    globalFunctions.map((function) => function.name).toSet()
      ..add("if")
      ..remove("abs")
      ..remove("alpha")
      ..remove("color")
      ..remove("grayscale")
      ..remove("hsl")
      ..remove("hsla")
      ..remove("hwb")
      ..remove("invert")
      ..remove("lab")
      ..remove("lch")
      ..remove("max")
      ..remove("min")
      ..remove("oklab")
      ..remove("oklch")
      ..remove("opacity")
      ..remove("rgb")
      ..remove("rgba")
      ..remove("round")
      ..remove("saturate");

class CssParser extends ScssParser {
  bool get plainCss => true;

  CssParser(super.contents, {super.url});

  bool silentComment() {
    if (inExpression) return false;

    var start = scanner.state;
    super.silentComment();
    error(
      "Silent comments aren't allowed in plain CSS.",
      scanner.spanFrom(start),
    );
  }

  Statement atRule(Statement child(), {bool root = false}) {
    // NOTE: this logic is largely duplicated in StylesheetParser.atRule. Most changes
    // here should be mirrored there.

    var start = scanner.state;
    scanner.expectChar($at);
    var name = interpolatedIdentifier();
    _whitespace();

    return switch (name.asPlain) {
      "at-root" ||
      "content" ||
      "debug" ||
      "each" ||
      "error" ||
      "extend" ||
      "for" ||
      "function" ||
      "if" ||
      "include" ||
      "mixin" ||
      "return" ||
      "warn" ||
      "while" =>
        _forbiddenAtRule(start),
      "import" => _cssImportRule(start),
      "media" => mediaRule(start),
      "-moz-document" => mozDocumentRule(start, name),
      "supports" => supportsRule(start),
      _ => unknownAtRule(start, name),
    };
  }

  /// Throws an error for a forbidden at-rule.
  Never _forbiddenAtRule(LineScannerState start) {
    almostAnyValue();
    error("This at-rule isn't allowed in plain CSS.", scanner.spanFrom(start));
  }

  /// Consumes a plain-CSS `@import` rule that disallows interpolation.
  ///
  /// [start] should point before the `@`.
  ImportRule _cssImportRule(LineScannerState start) {
    var urlStart = scanner.state;
    var url = switch (scanner.peekChar()) {
      $u || $U => switch (dynamicUrl()) {
          StringExpression string => string.text,
          InterpolatedFunctionExpression(
            :var name,
            arguments: ArgumentList(
              positional: [StringExpression string],
              named: Map(isEmpty: true),
              rest: null,
              keywordRest: null,
            ),
            :var span,
          ) =>
            (InterpolationBuffer()
                  ..addInterpolation(name)
                  ..writeCharCode($lparen)
                  ..addInterpolation(string.asInterpolation())
                  ..writeCharCode($rparen))
                .interpolation(span),
          // This shouldn't be reachable.
          var expression => error(
              "Unsupported plain CSS import.",
              expression.span,
            ),
        },
      _ => StringExpression(
          interpolatedString().asInterpolation(static: true),
        ).text,
    };

    _whitespace();
    var modifiers = tryImportModifiers();
    expectStatementSeparator("@import rule");
    return ImportRule([
      StaticImport(url, scanner.spanFrom(urlStart), modifiers: modifiers),
    ], scanner.spanFrom(start));
  }

  ParenthesizedExpression parentheses() {
    // Expressions are only allowed within calculations, but we verify this at
    // evaluation time.
    var start = scanner.state;
    scanner.expectChar($lparen);
    _whitespace();
    var expression = expressionUntilComma();
    scanner.expectChar($rparen);
    return ParenthesizedExpression(expression, scanner.spanFrom(start));
  }

  Expression identifierLike() {
    var start = scanner.state;
    var identifier = interpolatedIdentifier();
    var plain = identifier.asPlain!; // CSS doesn't allow non-plain identifiers

    var lower = plain.toLowerCase();
    if (trySpecialFunction(lower, start) case var specialFunction?) {
      return specialFunction;
    }

    var beforeArguments = scanner.state;
    // `namespacedExpression()` is just here to throw a clearer error.
    if (scanner.scanChar($dot)) return namespacedExpression(plain, start);
    if (!scanner.scanChar($lparen)) return StringExpression(identifier);

    var allowEmptySecondArg = lower == 'var';
    var arguments = <Expression>[];
    if (!scanner.scanChar($rparen)) {
      do {
        _whitespace();
        if (allowEmptySecondArg &&
            arguments.length == 1 &&
            scanner.peekChar() == $rparen) {
          arguments.add(StringExpression.plain('', scanner.emptySpan));
          break;
        }

        arguments.add(expressionUntilComma(singleEquals: true));
        _whitespace();
      } while (scanner.scanChar($comma));
      scanner.expectChar($rparen);
    }

    if (_disallowedFunctionNames.contains(plain)) {
      error(
        "This function isn't allowed in plain CSS.",
        scanner.spanFrom(start),
      );
    }

    return FunctionExpression(
      plain,
      ArgumentList(arguments, const {}, scanner.spanFrom(beforeArguments)),
      scanner.spanFrom(start),
    );
  }

  Expression namespacedExpression(String namespace, LineScannerState start) {
    var expression = super.namespacedExpression(namespace, start);
    error("Module namespaces aren't allowed in plain CSS.", expression.span);
  }

  /// The value of `consumeNewlines` is not relevant for this class.
  void _whitespace() {
    whitespace(consumeNewlines: true);
  }
}
