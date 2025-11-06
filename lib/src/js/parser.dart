// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../ast/node.dart';
import '../ast/sass.dart';
import '../exception.dart';
import '../js/visitor/simple_selector.dart';
import '../parse/parser.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../util/span.dart';
import '../util/lazy_file_span.dart';
import '../util/string.dart';
import '../visitor/interface/expression.dart';
import '../visitor/interface/interpolated_selector.dart';
import '../visitor/interface/statement.dart';
import 'reflection.dart';
import 'set.dart';
import 'utils.dart';
import 'visitor/expression.dart';
import 'visitor/statement.dart';

@JS()
@anonymous
class ParserExports {
  external factory ParserExports({
    required Function parse,
    required Function parseIdentifier,
    required Function toCssIdentifier,
    required Function createExpressionVisitor,
    required Function createStatementVisitor,
    required Function createSimpleSelectorVisitor,
    required Function createSourceFile,
    required Function setToJS,
    required Function mapToRecord,
  });

  external set parse(Function function);
  external set parseIdentifier(Function function);
  external set toCssIdentifier(Function function);
  external set createStatementVisitor(Function function);
  external set createExpressionVisitor(Function function);
  external set setToJS(Function function);
  external set mapToRecord(Function function);
}

/// An empty interpolation, used to initialize empty AST entries to modify their
/// prototypes.
final _interpolation = Interpolation(const [], const [], bogusSpan);

/// An expression used to initialize empty AST entries to modify their
/// prototypes.
final _expression = NullExpression(bogusSpan);

/// Loads and returns all the exports needed for the `sass-parser` package.
ParserExports loadParserExports() {
  _updateLazyFileSpanPrototype();
  _updateAstPrototypes();
  return ParserExports(
    parse: allowInterop(_parse),
    parseIdentifier: allowInterop(_parseIdentifier),
    toCssIdentifier: allowInterop(_toCssIdentifier),
    createExpressionVisitor: allowInterop(
      (JSExpressionVisitorObject inner) => JSExpressionVisitor(inner),
    ),
    createStatementVisitor: allowInterop(
      (JSStatementVisitorObject inner) => JSStatementVisitor(inner),
    ),
    createSimpleSelectorVisitor: allowInterop(
      (JSSimpleSelectorVisitorObject inner) => JSSimpleSelectorVisitor(inner),
    ),
    createSourceFile: allowInterop(
      (String text) => SourceFile.fromString(text),
    ),
    setToJS: allowInterop((Set<Object?> set) => JSSet([...set])),
    mapToRecord: allowInterop(mapToObject),
  );
}

/// Updates the prototype of [LazyFileSpan] to provide access to JS.
void _updateLazyFileSpanPrototype() {
  var span = LazyFileSpan(() => bogusSpan);
  getJSClass(span).defineGetters({
    'file': (LazyFileSpan span) => span.file,
    'length': (LazyFileSpan span) => span.length,
    'sourceUrl': (LazyFileSpan span) => span.sourceUrl,
  });
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
  getJSClass(file).defineMethods({
    'getText': (SourceFile self, int start, [int? end]) =>
        self.getText(start, end),
    'span': (SourceFile self, int start, [int? end]) => self.span(start, end),
  });
  getJSClass(
    file,
  ).defineGetter('codeUnits', (SourceFile self) => self.codeUnits);
  getJSClass(
    _interpolation,
  ).defineGetter('asPlain', (Interpolation self) => self.asPlain);
  getJSClass(ExtendRule(_interpolation, bogusSpan)).superclass.defineMethod(
        'accept',
        (Statement self, StatementVisitor<Object?> visitor) =>
            self.accept(visitor),
      );
  var string = StringExpression(_interpolation);
  getJSClass(string).superclass.defineMethod(
        'accept',
        (Expression self, ExpressionVisitor<Object?> visitor) =>
            self.accept(visitor),
      );
  var selector = InterpolatedParentSelector(bogusSpan);
  getJSClass(selector).superclass.defineMethod(
        'accept',
        (InterpolatedSelector self,
                InterpolatedSelectorVisitor<Object?> visitor) =>
            self.accept(visitor),
      );
  var arguments = ArgumentList([], {}, bogusSpan);
  getJSClass(
    IncludeRule('a', arguments, bogusSpan),
  ).defineGetter('arguments', (IncludeRule self) => self.arguments);
  getJSClass(
    ContentRule(arguments, bogusSpan),
  ).defineGetter('arguments', (ContentRule self) => self.arguments);
  getJSClass(
    FunctionExpression('a', arguments, bogusSpan),
  ).defineGetter('arguments', (FunctionExpression self) => self.arguments);
  getJSClass(
    LegacyIfExpression(arguments, bogusSpan),
  ).defineGetter('arguments', (LegacyIfExpression self) => self.arguments);
  getJSClass(
    InterpolatedFunctionExpression(_interpolation, arguments, bogusSpan),
  ).defineGetter(
      'arguments', (InterpolatedFunctionExpression self) => self.arguments);

  _addSupportsConditionToInterpolation();

  var klass = InterpolatedClassSelector(_interpolation);
  var compound = InterpolatedCompoundSelector([klass]);
  for (var node in [
    string,
    BinaryOperationExpression(BinaryOperator.plus, string, string),
    SupportsExpression(SupportsAnything(_interpolation, bogusSpan)),
    LoudComment(_interpolation),
    klass,
    InterpolatedIDSelector(_interpolation),
    InterpolatedPlaceholderSelector(_interpolation),
    InterpolatedTypeSelector(
        InterpolatedQualifiedName(_interpolation, bogusSpan)),
    compound,
    InterpolatedSelectorList([
      InterpolatedComplexSelector(
          [InterpolatedComplexSelectorComponent(compound, bogusSpan)],
          bogusSpan)
    ]),
  ]) {
    getJSClass(node).defineGetter('span', (AstNode self) => self.span);
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
    SupportsOperation(anything, anything, "and", bogusSpan),
  ]) {
    getJSClass(node).defineMethod(
      'toInterpolation',
      (SupportsCondition self) => self.toInterpolation(),
    );
  }
}

/// A JavaScript-friendly method to parse a stylesheet.
Stylesheet _parse(String css, String syntax, String? path) => Stylesheet.parse(
      css,
      switch (syntax) {
        'scss' => Syntax.scss,
        'sass' => Syntax.sass,
        'css' => Syntax.css,
        _ => throw UnsupportedError('Unknown syntax "$syntax"'),
      },
      url: path.andThen(p.toUri),
      parseSelectors: true,
    );

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
