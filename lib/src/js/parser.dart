// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../parse/parser.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../util/span.dart';
import '../util/string.dart';
import '../visitor/interface/expression.dart';
import '../visitor/interface/statement.dart';
import 'reflection.dart';
import 'set.dart';
import 'visitor/expression.dart';
import 'visitor/statement.dart';

@JS()
@anonymous
class ParserExports {
  external factory ParserExports(
      {required Function parse,
      required Function parseIdentifier,
      required Function toCssIdentifier,
      required Function createExpressionVisitor,
      required Function createStatementVisitor,
      required Function setToJS});

  external set parse(Function function);
  external set parseIdentifier(Function function);
  external set toCssIdentifier(Function function);
  external set createStatementVisitor(Function function);
  external set createExpressionVisitor(Function function);
  external set setToJS(Function function);
}

/// An empty interpolation, used to initialize empty AST entries to modify their
/// prototypes.
final _interpolation = Interpolation(const [], const [], bogusSpan);

/// An expression used to initialize empty AST entries to modify their
/// prototypes.
final _expression = NullExpression(bogusSpan);

/// Loads and returns all the exports needed for the `sass-parser` package.
ParserExports loadParserExports() {
  _updateAstPrototypes();
  return ParserExports(
      parse: allowInterop(_parse),
      parseIdentifier: allowInterop(_parseIdentifier),
      toCssIdentifier: allowInterop(_toCssIdentifier),
      createExpressionVisitor: allowInterop(
          (JSExpressionVisitorObject inner) => JSExpressionVisitor(inner)),
      createStatementVisitor: allowInterop(
          (JSStatementVisitorObject inner) => JSStatementVisitor(inner)),
      setToJS: allowInterop((Set<Object?> set) => JSSet([...set])));
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
  getJSClass(file)
      .defineGetter('codeUnits', (SourceFile self) => self.codeUnits);
  getJSClass(_interpolation)
      .defineGetter('asPlain', (Interpolation self) => self.asPlain);
  getJSClass(ExtendRule(_interpolation, bogusSpan)).superclass.defineMethod(
      'accept',
      (Statement self, StatementVisitor<Object?> visitor) =>
          self.accept(visitor));
  var string = StringExpression(_interpolation);
  getJSClass(string).superclass.defineMethod(
      'accept',
      (Expression self, ExpressionVisitor<Object?> visitor) =>
          self.accept(visitor));

  _addSupportsConditionToInterpolation();

  for (var node in [
    string,
    BinaryOperationExpression(BinaryOperator.plus, string, string),
    SupportsExpression(SupportsAnything(_interpolation, bogusSpan)),
    LoudComment(_interpolation)
  ]) {
    getJSClass(node).defineGetter('span', (SassNode self) => self.span);
  }
}

/// Updates the prototypes of [SupportsCondition] AST types to support
/// converting them to an [Interpolation] for the JS API.
///
/// Works around sass/sass#3935.
void _addSupportsConditionToInterpolation() {
  var anything = SupportsAnything(_interpolation, bogusSpan);
  for (var node in [
    anything,
    SupportsDeclaration(_expression, _expression, bogusSpan),
    SupportsFunction(_interpolation, _interpolation, bogusSpan),
    SupportsInterpolation(_expression, bogusSpan),
    SupportsNegation(anything, bogusSpan),
    SupportsOperation(anything, anything, "and", bogusSpan)
  ]) {
    getJSClass(node).defineMethod(
        'toInterpolation', (SupportsCondition self) => self.toInterpolation());
  }
}

/// A JavaScript-friendly method to parse a stylesheet.
Stylesheet _parse(String css, String syntax, String? path) => Stylesheet.parse(
    css,
    switch (syntax) {
      'scss' => Syntax.scss,
      'sass' => Syntax.sass,
      'css' => Syntax.css,
      _ => throw UnsupportedError('Unknown syntax "$syntax"')
    },
    url: path.andThen(p.toUri));

/// A JavaScript-friendly method to parse an identifier to its semantic value.
///
/// Returns null if [identifier] isn't a valid identifier.
String? _parseIdentifier(String identifier) {
  try {
    return Parser.parseIdentifier(identifier);
  } on SassFormatException {
    return null;
  }
}

/// A JavaScript-friendly method to convert text to a valid CSS identifier with
/// the same contents.
String _toCssIdentifier(String text) => text.toCssIdentifier();
