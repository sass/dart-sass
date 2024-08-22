// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../ast/sass.dart';
import '../logger.dart';
import '../logger/js_to_dart.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../util/span.dart';
import '../visitor/interface/expression.dart';
import '../visitor/interface/statement.dart';
import 'logger.dart';
import 'reflection.dart';
import 'visitor/expression.dart';
import 'visitor/statement.dart';

@JS()
@anonymous
class ParserExports {
  external factory ParserExports(
      {required Function parse,
      required Function createExpressionVisitor,
      required Function createStatementVisitor});

  external set parse(Function function);
  external set createStatementVisitor(Function function);
  external set createExpressionVisitor(Function function);
}

/// Loads and returns all the exports needed for the `sass-parser` package.
ParserExports loadParserExports() {
  _updateAstPrototypes();
  return ParserExports(
      parse: allowInterop(_parse),
      createExpressionVisitor: allowInterop(
          (JSExpressionVisitorObject inner) => JSExpressionVisitor(inner)),
      createStatementVisitor: allowInterop(
          (JSStatementVisitorObject inner) => JSStatementVisitor(inner)));
}

/// Modifies the prototypes of the Sass AST classes to provide access to JS.
///
/// This API is not intended to be used directly by end users and is subject to
/// breaking changes without notice. Instead, it's wrapped by the `sass-parser`
/// package which exposes a PostCSS-style API.
void _updateAstPrototypes() {
  // We don't need explicit getters for field names, because dart2js preserves
  // them as-is, so we actually need to expose very little to JS manually.
  var file = SourceFile.fromString('');
  getJSClass(file).defineMethod('getText',
      (SourceFile self, int start, [int? end]) => self.getText(start, end));
  var interpolation = Interpolation(const [], bogusSpan);
  getJSClass(interpolation)
      .defineGetter('asPlain', (Interpolation self) => self.asPlain);
  getJSClass(ExtendRule(interpolation, bogusSpan)).superclass.defineMethod(
      'accept',
      (Statement self, StatementVisitor<Object?> visitor) =>
          self.accept(visitor));
  var string = StringExpression(interpolation);
  getJSClass(string).superclass.defineMethod(
      'accept',
      (Expression self, ExpressionVisitor<Object?> visitor) =>
          self.accept(visitor));

  for (var node in [
    string,
    BinaryOperationExpression(BinaryOperator.plus, string, string),
    SupportsExpression(SupportsAnything(interpolation, bogusSpan)),
    LoudComment(interpolation)
  ]) {
    getJSClass(node).defineGetter('span', (SassNode self) => self.span);
  }
}

/// A JavaScript-friendly method to parse a stylesheet.
Stylesheet _parse(String css, String syntax, String? path, JSLogger? logger) =>
    Stylesheet.parse(
        css,
        switch (syntax) {
          'scss' => Syntax.scss,
          'sass' => Syntax.sass,
          'css' => Syntax.css,
          _ => throw UnsupportedError('Unknown syntax "$syntax"')
        },
        url: path.andThen(p.toUri),
        logger: JSToDartLogger(logger, Logger.stderr()));
