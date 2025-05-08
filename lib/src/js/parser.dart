// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:path/path.dart' as p;

import '../ast/sass.dart';
import '../exception.dart';
import '../parse/parser.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../util/string.dart';
import 'visitor/expression.dart';
import 'visitor/statement.dart';
import 'hybrid/binary_operation_expression.dart';
import 'hybrid/content_rule.dart';
import 'hybrid/expression.dart';
import 'hybrid/if_expression.dart';
import 'hybrid/include_rule.dart';
import 'hybrid/interpolated_function_expression.dart';
import 'hybrid/interpolation.dart';
import 'hybrid/loud_comment.dart';
import 'hybrid/source_file.dart';
import 'hybrid/statement.dart';
import 'hybrid/string_expression.dart';
import 'hybrid/supports_condition.dart';
import 'hybrid/supports_expression.dart';

extension type ParserExports._(JSObject _) implements JSObject {
  external ParserExports({
    required JSFunction parse,
    required JSFunction parseIdentifier,
    required JSFunction toCssIdentifier,
    required JSFunction createExpressionVisitor,
    required JSFunction createStatementVisitor,
    required JSFunction setToJS,
    required JSFunction mapToRecord,
  });

  external JSFunction parse;
  external JSFunction parseIdentifier;
  external JSFunction toCssIdentifier;
  external JSFunction createStatementVisitor;
  external JSFunction createExpressionVisitor;
  external JSFunction setToJS;
  external JSFunction mapToRecord;
}

/// Loads and returns all the exports needed for the `sass-parser` package.
ParserExports loadParserExports() {
  _updateAstPrototypes();
  return ParserExports(
    parse: _parse.toJS,
    parseIdentifier: _parseIdentifier.toJS,
    toCssIdentifier: _toCssIdentifier.toJS,
    createExpressionVisitor: ((JSExpressionVisitorObject inner) =>
        JSExpressionVisitor(inner).toExternalReference).toJS,
    createStatementVisitor: ((JSStatementVisitorObject inner) =>
        JSStatementVisitor(inner).toExternalReference).toJS,
    setToJS: ((JSAny set) => (set as Set<JSAny?>).toJS).toJS,
    mapToRecord: ((JSAny map) => (map as Map<JSString, JSAny?>).toJS).toJS,
  );
}

/// Modifies the prototypes of the Sass AST classes to provide access to JS.
///
/// This API is not intended to be used directly by end users and is subject to
/// breaking changes without notice. Instead, it's wrapped by the `sass-parser`
/// package which exposes a PostCSS-style API.
void _updateAstPrototypes() {
  SourceFileToJS.updatePrototype();
  InterpolationToJS.updatePrototype();
  StatementToJS.updatePrototype();
  ExpressionToJS.updatePrototype();
  IncludeRuleToJS.updatePrototype();
  ContentRuleToJS.updatePrototype();
  IfExpressionToJS.updatePrototype();
  InterpolatedFunctionExpressionToJS.updatePrototype();
  SupportsConditionToJS.updatePrototype();
  StringExpressionToJS.updatePrototype();
  BinaryOperationExpressionToJS.updatePrototype();
  SupportsExpressionToJS.updatePrototype();
  LoudCommentToJS.updatePrototype();
}

/// A JavaScript-friendly method to parse a stylesheet.
UnsafeDartWrapper<Statement> _parse(String css, String syntax, String? path) =>
    Stylesheet.parse(
            css,
            switch (syntax) {
              'scss' => Syntax.scss,
              'sass' => Syntax.sass,
              'css' => Syntax.css,
              _ => throw UnsupportedError('Unknown syntax "$syntax"'),
            },
            url: path.andThen(p.toUri))
        .toJS;

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
